import numpy as np
from compile_utils import *
import copy
import pickle
from read_ddr_data import read_output_file


# output_id_list, output_data = read_output_file("input.txt")

class Order(object):
    def __init__(self):
        self.layer_name = None
        self.ModuleList = None
        self.NameList = []
        self.allocate_memory = 0
        self.f_quant = 0
        self.w_quant = 0
        self.weight = None
        self.bias = None
        self.output_data = None
        self.id = None
        self.return_patch_num = None
        self.parameter = {"order": OrderType.IDLE.value,
                          "feature_input_base_addr": 0,
                          "feature_input_patch_num": 0,
                          "feature_output_patch_num": 0,
                          "feature_double_patch": 0,
                          "feature_patch_num": 0,
                          "row_size": 0,
                          "col_size": 0,
                          "weight_quant_size": 0,
                          "fea_in_quant_size": 0,
                          "fea_out_quant_size": 0,
                          "stride": 0,
                          "return_addr": 0,
                          "return_patch_num": 0,
                          "padding_size": 0,
                          "weight_data_length": 0,
                          "activate": 0,
                          "id": 0
                          }

    def ChangeParameter2Int(self):
        for key, value in self.parameter.items():
            self.parameter[key] = int(value)

    def MakeOrderString(self):
        OrderString = ""
        parameter_len = len(self.parameter)
        for i in range(parameter_len - 1, -1, -1):
            OrderString += hex(self.parameter[IdMapping(i)])[2:].zfill(8)
        return OrderString.zfill(256)

    def CompileOrder2Code(self):
        """8-bit addr and 32-bit data """
        OrderCode = []
        for key, value in self.parameter.items():
            Id = IdMapping(key)
            """ command 1 define set parameter"""
            OrderCode.append(hex(Id*4)[2:].zfill(2) + " " + hex(value)[2:].zfill(8))
        """ command 2 define Run Order"""
        OrderCode.append(hex(18*4)[2:].zfill(2) + " " + hex(0)[2:].zfill(8))
        return OrderCode

    def AllocateMemory(self, memory_point_input):
        return memory_point_input

    def SetInputMemory(self):
        pass

    def GetOutputQuant(self):
        return self.w_quant

    def MakeWeight(self):
        if self.weight is None:
            return None, None
        else:
            weight_temp = self.weight.copy()
            bias_temp = self.bias.copy()
            (out_c, in_c, k, _) = weight_temp.shape
            # weight_temp = np.ones((out_c, in_c, 1, 1), dtype=weight_temp.dtype) * np.power(2, self.w_quant)
            # self.weight = weight_temp
            # bias_temp = np.ones_like(bias_temp) * 12 * np.power(2, self.w_quant)
            # self.bias = bias_temp
            if k == _ == 1:
                z = np.zeros([out_c, in_c, 3, 3], dtype=weight_temp.dtype)
                z[:, :, 1, 1] = weight_temp.squeeze()
                weight_temp = z
                self.weight = weight_temp
            (out_c, in_c, k, _) = weight_temp.shape
            if out_c % 8 != 0:
                weight_temp = np.concatenate(
                    [weight_temp, np.zeros((8 - out_c % 8, in_c, k, _), dtype=weight_temp.dtype)], axis=0)
                bias_temp = np.concatenate([bias_temp, np.zeros(8 - out_c % 8)])
            (out_c, in_c, k, _) = weight_temp.shape
            if in_c % 16 != 0:
                weight_temp = np.concatenate(
                    [weight_temp, np.zeros((out_c, 16 - in_c % 16, k, _), dtype=weight_temp.dtype)], axis=1)
            (out_c, in_c, k, _) = weight_temp.shape
            assert out_c % 8 == 0
            assert in_c % 16 == 0
            assert k == _ == 3
            assert len(bias_temp) == out_c
            # reshape
            weight_nn = np.zeros((out_c, (in_c // 16), 9, 16), dtype=np.int16)
            for i in range(out_c):
                for j in range(0, in_c, 16):
                    for p in range(k):
                        for d in range(_):
                            weight_nn[i, (j // 16), p * _ + d, :] = weight_temp[i, j:j + 16, p, d]
            return weight_nn, bias_temp


class ConvOrder(Order):
    def __init__(self, input_layer, out_channel: int, stride: int, activate: bool = True):
        super(ConvOrder, self).__init__()
        padding = 1  # assert padding = 1
        self.input_layer = input_layer
        self.in_shape = input_layer.out_shape
        self.stride = stride - 1
        self.parameter['stride'] = self.stride
        self.padding = padding
        self.parameter['order'] = OrderType.CONVOLUTION.value
        self.parameter['padding_size'] = padding
        self.parameter['activate'] = activate
        self.activate = activate

        assert len(self.in_shape) == 3, "[Error] Input shape should be 3-dim"
        (c, w, h) = self.in_shape
        self.parameter['row_size'] = h
        self.parameter['col_size'] = w
        self.parameter['feature_input_patch_num'] = np.ceil(c / 16)
        self.parameter['feature_output_patch_num'] = np.ceil(out_channel / 8)
        # 小于8只启用第一个通道，大于8则两个通道都启用
        if c <= 8:
            self.parameter['feature_double_patch'] = 0
        else:
            self.parameter['feature_double_patch'] = 1

        output_w = w // 2 if stride == 2 else w
        output_h = h // 2 if stride == 2 else h
        self.out_shape = (out_channel, output_w, output_h)

        self.parameter['return_patch_num'] = StandardizedStorageSpace(output_w, output_h)
        self.return_patch_num = self.parameter['return_patch_num']
        self.using_space = self.parameter['return_patch_num'] * 4096 * np.ceil(out_channel / 8)

        assert input_layer.return_patch_num is not None, "[Error] input layer should have return patch num"
        self.parameter['feature_patch_num'] = input_layer.return_patch_num
        self.parameter['fea_in_quant_size'] = 7

    def AllocateMemory(self, memory_point_input):
        self.parameter['return_addr'] = memory_point_input
        self.allocate_memory = self.using_space // 1024
        return memory_point_input + self.using_space

    def SetInputMemory(self):
        self.parameter['feature_input_base_addr'] = self.input_layer.parameter['return_addr']

    def SetWeightAndBias(self, w_quant: int, weight, bias):
        self.f_quant = 7
        self.w_quant = w_quant
        self.parameter['fea_out_quant_size'] = 7
        assert w_quant != 0, "[Error] weight quant is zeros"
        self.parameter['weight_quant_size'] = w_quant - 1  # 因为0没有意义，会白占一个case电路，所以硬件上w_quant减1
        self.weight = weight
        self.bias = Quant(bias, self.f_quant + w_quant)

    def forward(self, simulation_data, simulation_id_list):
        data_index = simulation_id_list.index(self.id)
        s_data = ReshapeData(simulation_data[data_index], self.out_shape)
        conv_out_ac_quant, correct, is_zero = CompareConvResult(s_data, self.input_layer.output_data,
                                                                self.weight, self.bias, self.stride,
                                                                self.GetOutputQuant(), self.activate)
        print("%-30s%-20s%-20s" % (self.layer_name, ' compare ' + str(correct), 'is zeros ' + str(is_zero)))
        self.output_data = conv_out_ac_quant


class MaxPoolOrder(Order):
    def __init__(self, input_layer, stride: int):
        super(MaxPoolOrder, self).__init__()
        padding = 2  # assert padding = 2       // the max pool is for 5*5
        self.input_layer = input_layer
        self.in_shape = input_layer.out_shape
        self.stride = stride - 1
        self.parameter['stride'] = self.stride
        self.padding = padding
        self.parameter['order'] = OrderType.MAXPOOL.value
        self.parameter['padding_size'] = padding

        assert len(self.in_shape) == 3, "[Error] Input shape should be 3-dim"
        (c, w, h) = self.in_shape
        self.parameter['row_size'] = h
        self.parameter['col_size'] = w
        self.parameter['feature_input_patch_num'] = np.ceil(c / 8)
        self.parameter['feature_output_patch_num'] = np.ceil(c / 8)
        self.parameter['feature_double_patch'] = 0

        output_w = w // 2 if stride == 2 else w
        output_h = h // 2 if stride == 2 else h
        self.out_shape = (c, output_w, output_h)

        self.parameter['return_patch_num'] = StandardizedStorageSpace(output_w, output_h)
        self.return_patch_num = self.parameter['return_patch_num']
        self.using_space = self.parameter['return_patch_num'] * 4096 * np.ceil(c / 8)

        assert input_layer.return_patch_num is not None, "[Error] input layer should have return patch num"
        self.parameter['feature_patch_num'] = input_layer.return_patch_num
        self.parameter['fea_in_quant_size'] = 7

    def AllocateMemory(self, memory_point_input):
        self.parameter['return_addr'] = memory_point_input
        self.allocate_memory = self.using_space // 1024
        return memory_point_input + self.using_space

    def SetInputMemory(self):
        self.parameter['feature_input_base_addr'] = self.input_layer.parameter['return_addr']

    def forward(self, simulation_data, simulation_id_list):
        data_index = simulation_id_list.index(self.id)
        s_data = ReshapeData(simulation_data[data_index], self.out_shape)
        pool_out, correct, is_zero = ComparePoolResult(s_data, self.input_layer.output_data, self.stride)
        print("%-30s%-20s%-20s" % (self.layer_name, ' compare ' + str(correct), 'is zeros ' + str(is_zero)))
        self.output_data = pool_out


class UpsampleOrder(Order):
    def __init__(self, input_layer):
        super(UpsampleOrder, self).__init__()
        padding = 0  # assert padding = 0
        self.input_layer = input_layer
        self.in_shape = input_layer.out_shape
        self.stride = 0
        self.parameter['stride'] = self.stride
        self.padding = padding
        self.parameter['order'] = OrderType.UPSAMPLE.value
        self.parameter['padding_size'] = padding

        assert len(self.in_shape) == 3, "[Error] Input shape should be 3-dim"
        (c, w, h) = self.in_shape
        self.parameter['row_size'] = h
        self.parameter['col_size'] = w
        self.parameter['feature_input_patch_num'] = np.ceil(c / 8)
        self.parameter['feature_output_patch_num'] = np.ceil(c / 8)
        self.parameter['feature_double_patch'] = 0

        output_w = w * 2
        output_h = h * 2
        self.out_shape = (c, output_w, output_h)

        self.parameter['return_patch_num'] = StandardizedStorageSpace(output_w, output_h)
        self.return_patch_num = self.parameter['return_patch_num']
        self.using_space = self.parameter['return_patch_num'] * 4096 * np.ceil(c / 8)

        assert input_layer.return_patch_num is not None, "[Error] input layer should have return patch num"
        self.parameter['feature_patch_num'] = input_layer.return_patch_num
        self.parameter['fea_in_quant_size'] = 7

    def AllocateMemory(self, memory_point_input):
        self.parameter['return_addr'] = memory_point_input
        self.allocate_memory = self.using_space // 1024
        return memory_point_input + self.using_space

    def SetInputMemory(self):
        self.parameter['feature_input_base_addr'] = self.input_layer.parameter['return_addr']

    def forward(self, simulation_data, simulation_id_list):
        data_index = simulation_id_list.index(self.id)
        s_data = ReshapeData(simulation_data[data_index], self.out_shape)
        upsample_out, correct, is_zero = CompareUpSampleResult(s_data, self.input_layer.output_data)
        print("%-30s%-20s%-20s" % (self.layer_name, ' compare ' + str(correct), 'is zeros ' + str(is_zero)))
        self.output_data = upsample_out


class AddOrder(Order):
    '''
        independent_memory: this parameter is very import, if it is true, it will allocate a new memory for adder result
                            if it is false, the adder result will replace the data in inputLayerX2
    '''

    def __init__(self, inputLayerX1, inputLayerX2, independent_memory=False):
        super(AddOrder, self).__init__()
        self.inputLayerX1 = inputLayerX1
        self.inputLayerX2 = inputLayerX2
        self.parameter['order'] = OrderType.ADD.value
        self.parameter['padding_size'] = 0

        (c, w, h) = inputLayerX1.out_shape
        (self.parameter['col_size'], self.parameter['row_size']) = SplitInteger2MinimizeDifference(
            inputLayerX1.using_space // 2 // 8)
        self.parameter['feature_input_patch_num'] = 1
        self.parameter['feature_output_patch_num'] = 1
        self.parameter['feature_double_patch'] = 1

        self.out_shape = inputLayerX2.out_shape

        self.using_space = inputLayerX2.using_space
        self.parameter['return_patch_num'] = self.using_space // 4096
        self.return_patch_num = inputLayerX2.return_patch_num

        self.parameter['feature_patch_num'] = inputLayerX2.parameter['return_patch_num'] * inputLayerX2.parameter[
            'feature_output_patch_num']
        self.independent_memory = independent_memory

    def AllocateMemory(self, memory_point_input):
        if self.independent_memory:
            self.parameter['return_addr'] = memory_point_input
            return memory_point_input + self.inputLayerX2.using_space
        else:
            self.parameter['return_addr'] = self.inputLayerX2.parameter['return_addr']
            return memory_point_input

    def SetInputMemory(self):
        self.parameter['feature_input_base_addr'] = self.inputLayerX1.parameter['return_addr']

    def forward(self, simulation_data, simulation_id_list):
        data_index = simulation_id_list.index(self.id)
        s_data = ReshapeData(simulation_data[data_index], self.out_shape)
        add_out_ac_quant, correct, is_zero = CompareAddResult(s_data, [self.inputLayerX1.output_data,
                                                                       self.inputLayerX2.output_data])
        self.output_data = add_out_ac_quant
        print("%-30s%-20s%-20s" % (self.layer_name, ' compare ' + str(correct), 'is zeros ' + str(is_zero)))


class BottleneckOrder(Order):
    def __init__(self, input_layer, out_channel: int, e: float,
                 add: bool):
        super(BottleneckOrder, self).__init__()
        self.input_layer = input_layer
        self.in_shape = input_layer.out_shape
        (c, w, h) = self.in_shape
        self.conv1 = ConvOrder(input_layer=input_layer, out_channel=int(out_channel * e), stride=1)
        self.conv2 = ConvOrder(input_layer=self.conv1, out_channel=out_channel, stride=1)
        self.add = add
        if add:
            self.add = AddOrder(input_layer, self.conv2)
            self.ModuleList = [self.conv1, self.conv2, self.add]
            self.NameList = ['conv1', 'conv2', 'add']
            self.outputLayer = self.add
        else:
            self.ModuleList = [self.conv1, self.conv2]
            self.NameList = ['conv1', 'conv2']
            self.outputLayer = self.conv2
        self.Weight = []

    def SetWeightAndBias(self, w_quant: list, weight: list, bias: list):
        assert len(weight) == len(w_quant) == len(bias) == 2
        self.conv1.SetWeightAndBias(w_quant[0], weight[0], bias[0])
        self.conv2.SetWeightAndBias(w_quant[1], weight[1], bias[1])

    def forward(self, simulation_data, simulation_id_list):
        self.conv1.forward(simulation_data, simulation_id_list)
        self.conv2.forward(simulation_data, simulation_id_list)
        if self.add:
            self.add.forward(simulation_data, simulation_id_list)


class C2fOrder(Order):
    def __init__(self, input_layer, out_channel: int, n: int, add: bool = False,
                 e: float = 0.5):
        super(C2fOrder, self).__init__()
        self.input_layer = input_layer
        self.conv1 = ConvOrder(input_layer=input_layer, out_channel=int(2 * out_channel * e), stride=1)
        self.spilt = SpiltOrder(self.conv1)
        self.BottleList = []
        for _ in range(n):
            if _ == 0:
                self.BottleList.append(
                    BottleneckOrder(input_layer=self.spilt.VirtualLayer2, out_channel=int(out_channel * e), e=1,
                                    add=add))
            else:
                self.BottleList.append(
                    BottleneckOrder(input_layer=self.BottleList[-1].outputLayer, out_channel=int(out_channel * e),
                                    e=1, add=add))
        bottleListOutLayer = [bottle.outputLayer for bottle in self.BottleList]
        self.concat = ConcatOrder([self.spilt.VirtualLayer1, self.spilt.VirtualLayer2] + bottleListOutLayer)
        self.conv2 = ConvOrder(input_layer=self.concat, out_channel=out_channel, stride=1)
        self.ModuleList = [self.conv1, self.spilt] + self.BottleList + [self.concat, self.conv2]
        self.NameList = ['conv1', 'spilt']
        for Id, layer in enumerate(self.BottleList):
            self.NameList.append("Bottle" + str(Id))
        self.NameList += ['concat', 'conv2']
        self.outputLayer = self.ModuleList[-1]
        self.n = n
        self.Weight = []

    def SetWeightAndBias(self, w_quant: list, weight: list, bias: list):
        assert len(weight) == len(w_quant) == len(bias) == 2 + self.n * 2
        self.conv1.SetWeightAndBias(w_quant=w_quant[0], weight=weight[0], bias=bias[0])
        self.spilt.SetWeightAndBias(None, None, None)
        for i in range(self.n):
            self.BottleList[i].SetWeightAndBias(w_quant=w_quant[1 + i * 2:3 + i * 2],
                                                weight=weight[1 + i * 2:3 + i * 2], bias=bias[1 + i * 2:3 + i * 2])
        self.conv2.SetWeightAndBias(w_quant=w_quant[-1], weight=weight[-1], bias=bias[-1])

    def forward(self, simulation_data, simulation_id_list):
        self.conv1.forward(simulation_data, simulation_id_list)
        self.spilt.VirtualLayer1.output_data, self.spilt.VirtualLayer2.output_data = HalfSpiltArray(
            self.conv1.output_data)
        for bottle in self.BottleList:
            bottle.forward(simulation_data, simulation_id_list)
        self.concat.forward()
        self.conv2.forward(simulation_data, simulation_id_list)


class SPPFOrder(Order):
    def __init__(self, input_layer, out_channel: int):
        super(SPPFOrder, self).__init__()
        self.input_layer = input_layer
        self.conv1 = ConvOrder(input_layer=input_layer, out_channel=input_layer.out_shape[0] // 2, stride=1)
        # todo Maxpool
        self.maxpool1 = MaxPoolOrder(input_layer=self.conv1, stride=1)
        self.maxpool2 = MaxPoolOrder(input_layer=self.maxpool1, stride=1)
        self.maxpool3 = MaxPoolOrder(input_layer=self.maxpool2, stride=1)
        self.concat = ConcatOrder([self.conv1, self.maxpool1, self.maxpool2, self.maxpool3])
        self.conv2 = ConvOrder(input_layer=self.concat, out_channel=out_channel, stride=1)
        self.ModuleList = [self.conv1, self.maxpool1, self.maxpool2, self.maxpool3, self.concat, self.conv2]
        self.NameList = ['conv1', 'maxpool1', 'maxpool2', 'maxpool3', 'concat', 'conv2']
        self.outputLayer = self.ModuleList[-1]
        self.Weight = []

    def SetWeightAndBias(self, w_quant: list, weight: list, bias: list):
        assert len(weight) == len(w_quant) == len(bias) == 2
        self.conv1.SetWeightAndBias(w_quant=w_quant[0], weight=weight[0], bias=bias[0])
        self.conv2.SetWeightAndBias(w_quant=w_quant[-1], weight=weight[-1], bias=bias[-1])

    def forward(self, simulation_data, simulation_id_list):
        self.conv1.forward(simulation_data, simulation_id_list)
        # todo Maxpool
        self.maxpool1.forward(simulation_data, simulation_id_list)
        self.maxpool2.forward(simulation_data, simulation_id_list)
        self.maxpool3.forward(simulation_data, simulation_id_list)
        self.concat.forward()
        self.conv2.forward(simulation_data, simulation_id_list)


class DetectOrder(Order):
    def __init__(self, layerList, reg_max, class_num):
        super(DetectOrder, self).__init__()
        assert len(layerList) == 3, "Error: the layer input detect should be 3"
        self.layerList = layerList
        self.ModuleList = []
        self.cv2 = []
        self.cv2_name = []
        self.c2 = reg_max * 4
        self.reg_max = reg_max
        for i, inLayer in enumerate(layerList):
            inner_list = [ConvOrder(inLayer, self.c2, 1)]
            inner_list.append(ConvOrder(inner_list[-1], self.c2, 1))
            inner_list.append(ConvOrder(inner_list[-1], self.c2, 1, activate=False))

            inner_list_name = ["Cv2_" + str(i) + "_conv1",
                               "Cv2_" + str(i) + "_conv2",
                               "Cv2_" + str(i) + "_conv3", ]
            self.cv2 += inner_list
            self.cv2_name += inner_list_name
        self.cv3 = []
        self.c3 = class_num
        self.cv3_name = []
        for i, inLayer in enumerate(layerList):
            inner_list = [ConvOrder(inLayer, self.c3, 1)]
            inner_list.append(ConvOrder(inner_list[-1], self.c3, 1))
            inner_list.append(ConvOrder(inner_list[-1], self.c3, 1, activate=False))
            inner_list_name = ["Cv3_" + str(i) + "_conv1",
                               "Cv3_" + str(i) + "_conv2",
                               "Cv3_" + str(i) + "_conv3", ]
            self.cv3 += inner_list
            self.cv3_name += inner_list_name
        self.ModuleList = self.cv2 + self.cv3
        self.NameList = self.cv2_name + self.cv3_name

    def SetWeightAndBias(self, w_quant: list, weight: list, bias: list):
        assert len(weight) == len(w_quant) == len(bias) == 18
        for i, layer in enumerate(self.ModuleList):
            layer.SetWeightAndBias(w_quant[i], weight[i], bias[i])

    def forward(self, simulation_data, simulation_id_list):
        for layer in self.ModuleList:
            layer.forward(simulation_data, simulation_id_list)


class SpiltOrder(Order):
    def __init__(self, input_layer):
        super(SpiltOrder, self).__init__()
        self.input_layer = input_layer
        self.VirtualLayer1 = VirtualConvOrder(input_layer, 0)
        self.VirtualLayer2 = VirtualConvOrder(input_layer, 1)
        self.ModuleList = [self.VirtualLayer1, self.VirtualLayer2]
        self.NameList = ['virtual1', 'virtual2']

    def AllocateMemory(self, memory_point_input):
        memory_point_input = self.VirtualLayer1.AllocateMemory(memory_point_input)
        memory_point_input = self.VirtualLayer2.AllocateMemory(memory_point_input)
        return memory_point_input

    def SetWeightAndBias(self, w_quant, weight, bias):
        self.VirtualLayer1.SetWeightAndBias(w_quant, weight, bias)
        self.VirtualLayer2.SetWeightAndBias(w_quant, weight, bias)


class VirtualConvOrder(Order):
    def __init__(self, input_layer, index):
        super(VirtualConvOrder, self).__init__()
        self.input_layer = input_layer
        self.index = index
        (c, w, h) = input_layer.out_shape
        self.out_shape = (c // 2, w, h)
        self.using_space = input_layer.using_space // 2
        assert self.input_layer.return_patch_num is not None, "Error: input_layer.return_patch_num is None"
        self.parameter['return_patch_num'] = self.input_layer.return_patch_num
        self.return_patch_num = self.parameter['return_patch_num']
        self.parameter['feature_output_patch_num'] = self.input_layer.parameter['feature_output_patch_num'] // 2

    def AllocateMemory(self, memory_point_input):
        if self.index == 0:
            self.parameter['return_addr'] = self.input_layer.parameter['return_addr']
        else:
            self.parameter['return_addr'] = (self.input_layer.parameter['return_addr']
                                             + self.input_layer.using_space // 2)
        return memory_point_input

    def SetWeightAndBias(self, w_quant, weight, bias):
        self.parameter['fea_out_quant_size'] = 7


class MemcpyOrder(Order):
    def __init__(self, input_layer, otherLayer=None, toOtherLayer=False):
        super(MemcpyOrder, self).__init__()
        self.parameter['order'] = OrderType.MEMCPY.value
        self.toOtherLayer = toOtherLayer
        self.otherLayer = otherLayer
        self.input_layer = input_layer
        self.out_shape = input_layer.out_shape
        self.using_space = input_layer.using_space
        self.out_layer = otherLayer if self.toOtherLayer else self
        self.parameter['return_patch_num'] = self.input_layer.return_patch_num
        self.parameter['feature_output_patch_num'] = input_layer.parameter['feature_output_patch_num']

    def AllocateMemory(self, memory_point_input):
        if not self.toOtherLayer:
            self.parameter['return_addr'] = memory_point_input
            self.allocate_memory = self.using_space // 1024
            return memory_point_input + self.using_space
        else:
            self.parameter['return_addr'] = self.otherLayer.parameter['return_addr']
            return memory_point_input

    def SetInputMemory(self):
        self.parameter['feature_input_base_addr'] = self.input_layer.parameter['return_addr']

    def forward(self, simulation_data, simulation_id_list):
        data_index = simulation_id_list.index(self.id)
        s_data = ReshapeData(simulation_data[data_index], self.out_shape)
        correct = np.array_equal(s_data, self.input_layer.output_data)
        is_zero = np.array_equal(s_data, np.zeros_like(s_data))
        print("%-30s%-20s%-20s" % (self.layer_name, ' compare ' + str(correct), 'is zeros ' + str(is_zero)))
        self.output_data = self.input_layer.output_data


class ConcatOrder(Order):
    def __init__(self, layerList):
        super(ConcatOrder, self).__init__()
        # 确保输入的layerList的w， h维度一致
        for i in range(len(layerList) - 1):
            assert layerList[i + 1].out_shape[1:] == layerList[i].out_shape[1:], \
                "Error concat need the same input shape"

        self.layerList = layerList
        feature_output_patch_num = 0
        output_channel = 0
        for layer in layerList:
            feature_output_patch_num += layer.parameter['feature_output_patch_num']
            output_channel += layer.out_shape[0]
        self.parameter['return_patch_num'] = layerList[0].parameter['return_patch_num']
        self.return_patch_num = self.parameter['return_patch_num']
        self.parameter['feature_output_patch_num'] = np.ceil(output_channel / 8)
        (c, w, h) = self.layerList[0].out_shape
        self.out_shape = (output_channel, w, h)

    def AllocateMemory(self, memory_point_input):
        self.parameter['return_addr'] = self.layerList[0].parameter['return_addr']
        return memory_point_input

    def forward(self):
        self.output_data = np.concatenate([layer.output_data for layer in self.layerList], axis=0)


class VideoImage(Order):
    def __init__(self, VideoAddr, ImageShape: tuple):
        super(VideoImage, self).__init__()
        (w, h) = ImageShape
        self.VideoAddr = VideoAddr
        self.parameter['return_patch_num'] = StandardizedStorageSpace(w, h)
        self.return_patch_num = self.parameter['return_patch_num']
        self.parameter['return_addr'] = VideoAddr
        self.parameter['fea_out_quant_size'] = 7
        self.out_shape = (3, w, h)
        self.using_space = self.parameter['return_patch_num'] * 4096


class MyYolov8Model(object):
    def __init__(self, VideoAddr, ImageShape: tuple, FeatureSpaceAddr):
        super(MyYolov8Model, self).__init__()
        self.FeatureSpaceAddr = FeatureSpaceAddr
        self.video = VideoImage(VideoAddr, ImageShape)
        modelList = pickle.load(open('modelList.pkl', 'rb'))
        (conv_id, c2f_id, upsample_id, concat_id) = (0, 0, 0, 0)
        self.model = {}
        inLayer = self.video
        for model in modelList:
            if model['module'] == "Conv_Q":
                name = "Conv_Q" + str(conv_id)
                conv_id += 1
                self.model[name] = ConvOrder(inLayer, model['out_channel'], model['stride'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name]
            elif model['module'] == "C2f_Q":
                name = "C2f_Q" + str(c2f_id)
                c2f_id += 1
                self.model[name] = C2fOrder(inLayer, model['out_channel'], model['n'], model['add'], model['e'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name].outputLayer
            elif model['module'] == "SPPF_Q":
                name = "SPPF_Q"
                self.model[name] = SPPFOrder(inLayer, model['out_channel'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name].outputLayer
            elif model['module'] == "UPSAMPLE":
                name = "UPSAMPLE" + str(upsample_id)
                upsample_id += 1
                self.model[name] = UpsampleOrder(inLayer)
                inLayer = self.model[name]
            elif model['module'] == "CONCAT":
                name = "concat" + str(concat_id)
                concat_id += 1
                layer_list = []
                for i in model['layer_list']:
                    key = list(self.model.keys())
                    layer = self.model[key[i]]
                    layer_list.append(layer.outputLayer if hasattr(layer, 'outputLayer') else layer)
                self.model[name] = ConcatOrder(layer_list)
                inLayer = self.model[name]
            elif model['module'] == "DETECT_Q":
                name = "DETECT_Q"
                layer_list = []
                for i in model['layer_list']:
                    key = list(self.model.keys())
                    layer = self.model[key[i]]
                    layer_list.append(layer.outputLayer if hasattr(layer, 'outputLayer') else layer)
                self.model[name] = DetectOrder(layer_list, model['reg_max'], model['class'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
            else:
                raise Exception("Error ridiculous module")
            self.weight = []
            self.bias = []
            self.weightAndBias = None

    def FlattenLayer(self, model, insert_name=False):
        layerList = []
        layerName = []
        for name, layer in model.items():
            if layer.ModuleList is None:
                layerList.append(layer)
                if insert_name:
                    layer.layer_name = name
                layerName.append(name)
            else:
                childName, childLayer = self.GetChildLayer(layer, name)
                for i in range(len(childLayer)):
                    layerList.append(childLayer[i])
                    if insert_name:
                        childLayer[i].layer_name = childName[i]
                    layerName.append(childName[i])
        return layerName, layerList

    def GetChildLayer(self, layer, fatherName):
        childLayer = []
        childName = []
        for Id, l in enumerate(layer.ModuleList):
            if l.ModuleList is None:
                childLayer.append(l)
                childName.append(fatherName + '.' + layer.NameList[Id])
            else:
                ccName, ccLayer = self.GetChildLayer(l, layer.NameList[Id])
                for i in range(len(ccLayer)):
                    childLayer.append(ccLayer[i])
                    childName.append(fatherName + '.' + ccName[i])
        return childName, childLayer

    def AllocateMemory(self):
        memory_point = self.FeatureSpaceAddr
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        ff = copy.deepcopy(flattenName)
        # 调整concat、adder层指向的对象的排列顺序
        for layer in ff:
            if "concat" in layer:
                index = flattenName.index(layer)
                replace_list = []
                for i, l in enumerate(flattenLayer[index].layerList):
                    if isinstance(l, AddOrder):
                        if not l.independent_memory:
                            replace_list.append(l.inputLayerX2)
                        else:
                            replace_list.append(l)
                    else:
                        replace_list.append(l)
                flattenLayer, flattenName = reorderPosition(flattenLayer, replace_list, flattenName)
                # # 删除concat层
                # flattenName.remove(layer)
                # flattenLayer.pop(index)
            elif "add" in layer:
                index = flattenName.index(layer)
                flattenLayer, flattenName = reorderPosition(flattenLayer, [flattenLayer[index].inputLayerX1,
                                                                           flattenLayer[index].inputLayerX2],
                                                            flattenName)
        print("Before allocate memory: {} KB".format(memory_point // 1024))
        for i, layer in enumerate(flattenLayer):
            name = flattenName[i]
            memory_point = layer.AllocateMemory(memory_point)
        print("After allocate memory: {} KB total allocate {} KB".format(memory_point // 1024, (
                memory_point - self.FeatureSpaceAddr) // 1024))

        # connect to input layer
        for layer in flattenLayer:
            layer.SetInputMemory()

    def PrintModelMemoryUsing(self):
        print("---------------------- Model memory allocate summary ---------------------- ")
        print("%-30s%20s%20s%20s" % ("layer name", "using space", "Start Address", "params"))
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        total_space = 0
        total_params = 0
        for index, layer in enumerate(flattenLayer):
            params = None if layer.weight is None else layer.weight.reshape(-1).shape[0]
            print("%-30s%20s%20s%20s" % (flattenName[index], str(layer.allocate_memory) + "KB",
                                         "0x" + hex(layer.parameter['return_addr'])[2:].zfill(8), params))
            total_space += layer.allocate_memory
            total_params = total_params + params if params is not None else total_params
        print("%-30s%20s%20s%20s" % ("total", total_space, "-", total_params))

    def IntParameter(self):
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        for layer in flattenLayer:
            layer.ChangeParameter2Int()

    def MakeWeight(self):
        Weight = []
        bias = []
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        for layer in flattenLayer:
            w, b = layer.MakeWeight()
            if w is not None:
                Weight.append(w)
                bias.append(b)

        return Weight, bias

    def MakeWeightBiasBin(self):
        # 8个输出通道一组
        WeightAndBias = []
        for i in range(len(self.weight)):
            w = self.weight[i]
            b = self.bias[i]
            (out_c, in_c, _, _) = w.shape
            assert len(b) == out_c
            for j in range(0, out_c, 8):
                patch_w = w[j:j + 8, :, :, :]
                patch_b = b[j:j + 8]
                for d in range(in_c):
                    WeightAndBias.append(patch_w[:, d, :, :].reshape(-1).tobytes())
                    if d == 0:
                        WeightAndBias.append(patch_b.reshape(-1).astype(np.int32).tobytes())
        with open("WeightAndBias.bin", "wb") as f:
            for by in WeightAndBias:
                f.write(by)
        return WeightAndBias

    def GenerateOrder(self):
        order = []
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        index = 0
        for layer in flattenLayer:
            if isinstance(layer, (ConvOrder, AddOrder, MemcpyOrder, MaxPoolOrder, UpsampleOrder)):
                layer.id = index
                layer.parameter['id'] = index
                order.append(layer.MakeOrderString())
                index += 1
        with open("order.txt", 'w') as f:
            zeros_l = 128 - len(order)
            for order in order:
                f.write(order)
                f.write('\n')
            for i in range(zeros_l):
                f.write("0".zfill(256))
                f.write('\n')

    def GenerateCode(self):
        code = []
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        index = 0
        code.append(hex(20*4)[2:].zfill(2) + " " + hex(0)[2:].zfill(8))
        for layer in flattenLayer:
            if isinstance(layer, (ConvOrder, AddOrder, MemcpyOrder, MaxPoolOrder, UpsampleOrder)):
                layer.id = index
                layer.parameter['id'] = index
                code += layer.CompileOrder2Code()
                index += 1
        with open("order_code.txt", 'w') as f:
            for o in code:
                f.write(o)
                f.write('\n')

    def SetWeightLength(self):
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        for layer in flattenLayer:
            layer.parameter['weight_data_length'] = 0x11A4000

    def Build(self, code=False):
        self.AllocateMemory()
        self.IntParameter()
        self.PrintModelMemoryUsing()
        self.FlattenLayer(self.model, insert_name=True)
        self.weight, self.bias = self.MakeWeight()
        self.weightAndBias = self.MakeWeightBiasBin()
        self.SetWeightLength()
        if code:
            self.GenerateCode()
        else:
            self.GenerateOrder()

    @staticmethod
    def RemoveNoCalculateLayers(layerName, layerList):
        index = []
        for i, layer in enumerate(layerList):
            if isinstance(layer, (VirtualConvOrder, ConcatOrder)):
                index.append(i)
        layerList = [layerList[i] for i in range(len(layerList)) if i not in index]
        layerName = [layerName[i] for i in range(len(layerName)) if i not in index]
        return layerName, layerList

    def CompareResult(self, simulation_data, simulation_id_list):
        self.video.output_data = ReshapeData(simulation_data[0], self.video.out_shape)
        simulation_data.pop(0)
        simulation_id_list.pop(0)
        for name, layer in self.model.items():
            if isinstance(layer, (ConvOrder, C2fOrder, SPPFOrder, UpsampleOrder, DetectOrder)):
                layer.forward(simulation_data, simulation_id_list)
            elif isinstance(layer, ConcatOrder):
                layer.forward()

    def ReturnNetworkOutput(self):
        box = []
        cls = []
        for i in range(3):
            cv2_out = deQuant(self.model['DETECT_Q'].cv2[3 * i + 2].output_data, 7)
            cv3_out = deQuant(self.model['DETECT_Q'].cv3[3 * i + 2].output_data, 7)
            box.append(cv2_out)
            cls.append(cv3_out)
        anchor, stride, box, cls = MakeAnchors(box, cls)
        box = np.concatenate(box, axis=1)
        cls = np.concatenate(cls, axis=1)

        box_valid, cls_valid, anchor_valid, stride_valid = SelectValidBox(box, cls, anchor, stride)
        box_list = DFL(box_valid, self.model['DETECT_Q'].reg_max, anchor_valid, stride_valid)
        label = np.argmax(cls_valid, axis=0)
        box_nms = []
        label_nms = []
        for i in range(self.model['DETECT_Q'].c3):
            select = label == i
            box_remain = NonMaximumSuppression(box_list[select, :], cls_valid[i, select], 0.5)
            box_nms += box_remain
            label_nms += [i for j in range(len(box_remain))]
        box_nms = np.stack(box_nms, axis=0)
        label_nms = np.stack(label_nms, axis=0)
        return box_list, label, box_nms, label_nms



if __name__ == '__main__':
    MyYolov8Model(0, (640, 480), 0x2800000)
