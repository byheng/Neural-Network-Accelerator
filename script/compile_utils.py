from enum import Enum
import numpy as np
import torch
from torch.nn.functional import conv2d


class OrderType(Enum):
    IDLE = 0
    CONVOLUTION = 1
    ADD = 2


def IdMapping(Id):
    MappingDict = {"order": 0,
                   "feature_input_base_addr": 1,
                   "feature_input_patch_num": 2,
                   "feature_output_patch_num": 3,
                   "feature_double_patch": 4,
                   "feature_patch_num": 5,
                   "row_size": 6,
                   "col_size": 7,
                   "weight_quant_size": 8,
                   "fea_in_quant_size": 9,
                   "fea_out_quant_size": 10,
                   "stride": 11,
                   "return_addr": 12,
                   "return_patch_num": 13,
                   "padding_size": 14,
                   "weight_data_length": 15
                   }
    if isinstance(Id, int):
        for key, value in MappingDict.items():
            if Id == value:
                return key
        raise ValueError("[Error] Invalid Id")
    elif isinstance(Id, str):
        return MappingDict.get(Id, '[Error] Invalid Key name')

    raise ValueError("[Error] You must use Id to catch Key or Use Key to catch Id")


def StandardizedStorageSpace(w, h):
    stand_f = np.ceil(w * h / 256)
    return stand_f


def SplitInteger2MinimizeDifference(n):
    sqrt_n = int(np.sqrt(n))
    for i in range(sqrt_n, 0, -1):
        if n % i == 0:
            return i, n // i


class NameGenerator(object):
    def __init__(self, typeList):
        self.typeList = typeList
        self.nameNum = np.ones(len(self.typeList))

    def reset(self):
        self.nameNum = np.ones(len(self.typeList))

    def generateName(self, typeE):
        name = ""
        for index, typeName in enumerate(self.typeList):
            if isinstance(typeE, typeName):
                Id = self.nameNum[index]
                name = typeE.__class__.__name__ + "_" + str(int(Id))
                self.nameNum[index] += 1
        if name == "":
            name = "Unknown Type"
        return name


"""
    list2是list1的子集，list3是list1的一一映射，此函数将list2中的元素在list1中的位置移到一起，同时list3也会做相同的变化。
    例如：
        list1 = [1, 3, 6, 9, 8, 10]
        list2 = [6, 3, 10]
        list3 = ['a', 'b', 'c', 'd', 'e', 'f']
        new_list1, new_list3 = reorder_lists_fixed_position(list1, list2, list3)
        print(new_list1)  # [1, 6, 3, 10, 9, 8]
        print(new_list3)  # ['a', 'c', 'b', 'f', 'd', 'e']
"""


def reorderPosition(list1, list2, list3):
    first_element = list2[0]
    first_index = list1.index(first_element)

    # 构建索引映射
    index_map = {value: i for i, value in enumerate(list1)}

    # 按 list2 的顺序提取元素，排除第一个元素
    subset1 = [item for item in list1 if item in list2 and item != first_element]
    subset3 = [list3[index_map[item]] for item in subset1]

    # 剩余部分的元素
    rest1 = [item for item in list1 if item not in list2]
    rest3 = [list3[index_map[item]] for item in rest1]

    # 确保第一个元素位置不变
    new_list1 = rest1[:first_index] + [first_element] + subset1 + rest1[first_index:]
    new_list3 = rest3[:first_index] + [list3[index_map[first_element]]] + subset3 + rest3[first_index:]

    return new_list1, new_list3


def CheckContinuity(list1, list2, list3):
    # 获取 list2 中每个元素在 list1 中的索引
    indices = [list1.index(value) for value in list2 if value in list1]

    # 检查索引是否连续
    is_list1_continuous = all(indices[i] + 1 == indices[i + 1] for i in range(len(indices) - 1))

    # 提取 list3 的映射部分
    mapped_values = [list3[list1.index(value)] for value in list2 if value in list1]

    # 检查映射是否连续
    is_list3_continuous = all(
        list3.index(mapped_values[i]) + 1 == list3.index(mapped_values[i + 1])
        for i in range(len(mapped_values) - 1)
    )

    return is_list1_continuous, is_list3_continuous


def Quant(x, bit):
    if isinstance(x, torch.Tensor):
        x = x.detach().cpu().numpy()
    scale = 2 ** bit
    return np.floor(x * scale)


def deQuant(x, bit):
    if isinstance(x, torch.Tensor):
        x = x.detach().cpu().numpy()
    scale = 2 ** bit
    return x / scale


def MakePictureBin(picture):
    picture = np.concatenate([picture, np.zeros((1, 5, 480, 640))], axis=1).squeeze().astype(np.int16)
    picture = picture.transpose(1, 2, 0)
    with open("picture.bin", 'wb') as f:
        f.write(picture.tobytes())


def CompareConvResult(simulation_result, input_data, w, b, stride, quant):
    input_data = torch.from_numpy(input_data.astype(np.int64))
    (out_c, in_c, _, _) = w.shape
    z = np.zeros([out_c, in_c, 3, 3], dtype=w.dtype)
    z[:, :, 1, 1] = w.squeeze()
    w = z
    w = torch.from_numpy(w.astype(np.int64))
    b = torch.from_numpy(b.astype(np.int64))



    out = conv2d(input_data, weight=w, bias=b, stride=stride + 1, padding=1)
    conv_out_ac = torch.relu(out).detach().cpu().numpy()
    conv_out_ac_quant = conv_out_ac // pow(2, quant)
    conv_out_ac_quant = conv_out_ac_quant.astype(np.int16)
    conv_out = out.detach().cpu().numpy()

    correct = np.array_equal(conv_out_ac_quant, simulation_result)
    is_zero = np.array_equal(conv_out_ac_quant, np.zeros_like(conv_out_ac_quant))

    return conv_out_ac_quant, correct, is_zero


def GetConvDataFromMemory(memory, shape, first_addr, length):
    first_addr = int(first_addr)
    length = int(length)
    assert len(shape) == 3
    (c, w, h) = shape
    c_i = np.ceil(c / 8).astype(np.int64) * 8
    f_start = first_addr // 2
    f_end = (first_addr + length) // 2
    output = memory[f_start:f_end].reshape(-1).reshape(c_i // 8, -1, 8).transpose(0, 2, 1).reshape(c_i, -1)[:c, :]
    output = output[:, :h * w].reshape(c, h, w)

    return output


if __name__ == "__main__":
    result = SplitInteger2MinimizeDifference(3400)
    print(result)
