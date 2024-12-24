from enum import Enum
import numpy as np
import torch
from torch.nn.functional import conv2d, pad, max_pool2d, upsample, interpolate
import cv2

label_dict = ["person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light",
              "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
              "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
              "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard",
              "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
              "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
              "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote", "keyboard",
              "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors",
              "teddy bear", "hair drier", "toothbrush"]


class OrderType(Enum):
    IDLE = 0
    CONVOLUTION = 1
    ADD = 2
    MAXPOOL = 3
    UPSAMPLE = 4
    MEMCPY = 5


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
                   "weight_data_length": 15,
                   "activate": 16,
                   "id": 17
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
    shift_index = 0
    for item in list2:
        if item != first_element:
            if list1.index(item) < first_index:
                shift_index += 1
    # 构建索引映射
    index_map = {value: i for i, value in enumerate(list1)}

    # 按 list2 的顺序提取元素，排除第一个元素
    subset1 = [item for item in list1 if item in list2 and item != first_element]
    subset3 = [list3[index_map[item]] for item in subset1]

    # 剩余部分的元素
    rest1 = [item for item in list1 if item not in list2]
    rest3 = [list3[index_map[item]] for item in rest1]

    # 确保第一个元素位置不变
    new_list1 = rest1[:first_index - shift_index] + [first_element] + subset1 + rest1[first_index - shift_index:]
    new_list3 = rest3[:first_index - shift_index] + [list3[index_map[first_element]]] + subset3 + rest3[
                                                                                                  first_index - shift_index:]

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
    x = x.astype(np.float32)
    return x / scale


def MakePictureBin(picture):
    picture = np.concatenate([picture, np.zeros((480, 640, 5))], axis=2).squeeze().astype(np.int16)
    with open("picture.bin", 'wb') as f:
        f.write(picture.tobytes())


def CompareConvResult(simulation_result, input_data, w, b, stride, quant, activate):
    input_data = torch.from_numpy(input_data.astype(np.int64))
    w = torch.from_numpy(w.astype(np.int64))
    b = torch.from_numpy(b.astype(np.int64))

    out = conv2d(input_data, weight=w, bias=b, stride=stride + 1, padding=1)
    conv_out_ac = torch.relu(out).detach().cpu().numpy() if activate else out.detach().cpu().numpy()
    conv_out_ac_quant = conv_out_ac // pow(2, quant)
    conv_out_ac_quant = conv_out_ac_quant.astype(np.int16)
    conv_out = out.detach().cpu().numpy()

    correct = np.array_equal(conv_out_ac_quant, simulation_result)
    is_zero = np.array_equal(conv_out_ac_quant, np.zeros_like(conv_out_ac_quant))

    return conv_out_ac_quant, correct, is_zero


def ComparePoolResult(simulation_result, input_data, stride):
    input_data = torch.from_numpy(input_data.astype(np.int64))

    out = max_pool2d(input_data, kernel_size=5, stride=stride + 1, padding=2)
    pool_out = out.detach().cpu().numpy()

    correct = np.array_equal(pool_out, simulation_result)
    is_zero = np.array_equal(pool_out, np.zeros_like(pool_out))

    return pool_out, correct, is_zero


def CompareUpSampleResult(simulation_result, input_data):
    input_data = torch.from_numpy(input_data.astype(np.float32)).unsqueeze(0)

    out = interpolate(input_data, scale_factor=2, mode='nearest').squeeze()
    upsample_out = out.detach().cpu().numpy().astype(np.int32)

    correct = np.array_equal(upsample_out, simulation_result)
    is_zero = np.array_equal(upsample_out, np.zeros_like(upsample_out))

    return upsample_out, correct, is_zero


def CompareAddResult(simulation_result, input_data):
    output_data = input_data[0] + input_data[1]
    correct = np.array_equal(output_data, simulation_result)
    is_zero = np.array_equal(output_data, np.zeros_like(output_data))
    return output_data, correct, is_zero


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


def ReshapeData(data, shape):
    assert len(shape) == 3
    (c, w, h) = shape
    c_i = np.ceil(c / 8).astype(np.int64) * 8
    output = data.reshape(-1).reshape(c_i // 8, -1, 8).transpose(0, 2, 1).reshape(c_i, -1)[:c, :]
    output = output[:, :h * w].reshape(c, h, w)

    return output


def HalfSpiltArray(input_data):
    (c, _, _) = input_data.shape
    return input_data[:c // 2, :, :], input_data[c // 2:, :, :]


def SelectValidBox(box, cls, anchor, stride, conf=0.20):
    logit = np.log(conf / (1 - conf))
    # 当cls输出的最大值小于logit时，则可排除
    b_max = cls.max(axis=0)
    b_valid = b_max > logit
    box_valid = box[:, b_valid]
    cls_valid = Sigmoid(cls[:, b_valid])
    anchor_valid = anchor[b_valid, :]
    stride_valid = stride[b_valid, :]
    return box_valid, cls_valid, anchor_valid, stride_valid


def MakeAnchors(box, cls, strides=(8, 16, 32)):
    anchor_points, stride_list = [], []
    for i, stride in enumerate(strides):
        _, h, w = box[i].shape
        sx = np.arange(start=0, stop=w, dtype=box[i].dtype) + 0.5
        sy = np.arange(start=0, stop=h, dtype=box[i].dtype) + 0.5
        sy, sx = np.meshgrid(sy, sx, indexing="ij")
        anchor_points.append(np.stack((sx, sy), axis=-1).reshape(-1, 2))
        stride_list.append(np.full((h * w, 1), stride, dtype=box[i].dtype))
        box[i] = box[i].reshape(_, -1)
        cls[i] = cls[i].reshape(cls[i].shape[0], -1)
    return np.concatenate(anchor_points), np.concatenate(stride_list), box, cls


def Softmax(data, dim):
    max_values = np.max(data, axis=dim, keepdims=True)
    exp_data = np.exp(data - max_values)

    sum_exp = np.sum(exp_data, axis=dim, keepdims=True)
    return exp_data / sum_exp


def Sigmoid(data):
    return 1 / (1 + np.exp(-data))


def DFL(box, reg_max, anchor, stride, xywh=False):
    assert box.shape[0] == 4 * reg_max, "Error: first dim should be 4 * reg_max"
    box = box.reshape(4, reg_max, -1)
    # softmax
    box_softmax = Softmax(box, dim=1)
    # conv DFL
    kernel = np.arange(16).reshape(1, 16, 1)
    result = np.sum(box_softmax * kernel, axis=1, keepdims=True).squeeze()
    # depacked to xywh
    result = result.transpose(1, 0)
    lt, rb = (result[:, :2], result[:, 2:])
    x1y1 = anchor - lt
    x2y2 = anchor + rb
    if xywh:
        c_xy = (x1y1 + x2y2) / 2
        wh = x2y2 - x1y1
        box_xywh = np.concatenate((c_xy, wh), axis=1) * stride
        return box_xywh
    else:
        box = np.concatenate((x1y1, x2y2), axis=1) * stride
        return box


def NonMaximumSuppression(box, score, iou_threshold=0.5):
    """
    实现非极大抑制（NMS）。

    参数：
    - boxes: numpy.ndarray, 形状为 (N, 4)，每一行表示一个边界框 [x1, y1, x2, y2]。
    - scores: numpy.ndarray, 形状为 (N,)，每个边界框的置信分数。
    - iou_threshold: float, IOU 阈值，超过此值的框会被抑制。

    返回：
    - keep: list，保留的边界框索引。
    """
    if len(box) == 0:
        return []

    # 计算每个框的面积
    x1, y1, x2, y2 = box[:, 0], box[:, 1], box[:, 2], box[:, 3]
    areas = (x2 - x1 + 1) * (y2 - y1 + 1)

    # 按置信分数降序排序
    order = score.argsort()[::-1]

    keep = []  # 存储保留下来的边界框索引

    while order.size > 0:
        # 当前分数最高的框
        i = order[0]
        keep.append(box[i, :])

        # 计算当前框与其他框的 IOU
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])

        # 计算交集面积
        inter_width = np.maximum(0, xx2 - xx1 + 1)
        inter_height = np.maximum(0, yy2 - yy1 + 1)
        intersection = inter_width * inter_height

        # 计算 IOU（交并比）
        iou = intersection / (areas[i] + areas[order[1:]] - intersection)

        # 保留 IOU 小于阈值的框
        inds = np.where(iou <= iou_threshold)[0]
        order = order[inds + 1]

    return keep


def ShowPicture(boxes, label, image, imageName, save=False):
    img = image.copy()
    img = img.astype(np.uint8)
    for i in range(boxes.shape[0]):
        lp = (int(boxes[i, 0]), int(boxes[i, 1]))
        rb = (int(boxes[i, 2]), int(boxes[i, 3]))
        cv2.rectangle(img, lp, rb, (0, 255, 0), 2)
        cv2.putText(img, label_dict[label[i]], (lp[0], lp[1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 1)
    if save:
        cv2.imwrite(imageName + ".png", img)
    cv2.imshow(imageName, img)
    cv2.waitKey(0)


def letterbox(img, target_size=(640, 480), color=(114, 114, 114), auto=True, scale_fill=False, scale_up=True):
    """
    Resize and pad image to meet the target size using letterboxing.

    Args:
        img (numpy.ndarray): Original input image.
        target_size (tuple): Target size (width, height).
        color (tuple): Padding color (default is gray, (114, 114, 114)).
        auto (bool): Whether to automatically adjust size to be divisible by 32.
        scale_fill (bool): Whether to force resize to target size without padding.
        scale_up (bool): Allow scaling up if the input image is smaller than target size.

    Returns:
        padded_img (numpy.ndarray): Letterboxed image.
        ratio (tuple): Width and height scaling ratio.
        padding (tuple): Padding added to (top, bottom, left, right).
    """
    # Original image shape
    h, w = img.shape[:2]
    target_w, target_h = target_size

    # Scale ratio (new / old)
    scale = min(target_w / w, target_h / h)
    if not scale_up:
        scale = min(scale, 1.0)

    # Compute resized image size
    new_w, new_h = int(w * scale), int(h * scale)

    # Resize the image
    resized_img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

    # Compute padding
    dw, dh = target_w - new_w, target_h - new_h  # Width and height padding
    if auto:  # Make padding even on both sides
        dw, dh = np.mod(dw, 32), np.mod(dh, 32)
    dw //= 2
    dh //= 2

    # Add border (padding)
    padded_img = cv2.copyMakeBorder(resized_img, dh, target_h - new_h - dh, dw, target_w - new_w - dw,
                                    cv2.BORDER_CONSTANT, value=color)

    # Return the padded image, scaling ratio, and padding info
    return padded_img, (scale, scale), (dw, dh)


def ChangeBGR2RGB(image):
    image = image.copy()
    image = image[..., ::-1]
    return image


if __name__ == "__main__":
    result = SplitInteger2MinimizeDifference(3400)
    print(result)
