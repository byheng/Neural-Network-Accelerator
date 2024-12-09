import numpy as np
from compile_utils import *
import copy
import pickle


class Order(object):
    def __init__(self):
        self.ModuleList = None
        self.NameList = []
        self.allocate_memory = 0
        self.f_quant = 0
        self.w_quant = 0
        self.weight = None
        self.bias = None
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
                          "weight_data_length": 0
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
        """8-bit command 8-bit addr and 32-bit data """
        OrderCode = []
        for key, value in self.parameter.items():
            Id = IdMapping(key)
            """ command 1 define set parameter"""
            OrderCode.append(hex(1)[2:].zfill(2) + hex(Id)[2:].zfill(2) + hex(value)[2:].zfill(8))
        """ command 2 define Run Order"""
        OrderCode.append(hex(2)[2:].zfill(2) + hex(0)[2:].zfill(10))
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
            weight_temp = np.ones((out_c, in_c, 1, 1), dtype=weight_temp.dtype) * np.power(2, self.w_quant)
            self.weight = weight_temp
            bias_temp = np.ones_like(bias_temp) * 12 * np.power(2, self.w_quant)
            self.bias = bias_temp
            if out_c % 8 != 0:
                weight_temp = np.concatenate(
                    [weight_temp, np.zeros((8 - out_c % 8, in_c, k, _), dtype=weight_temp.dtype)], axis=0)
                bias_temp = np.concatenate([bias_temp, np.zeros(8 - out_c % 8)])
            (out_c, in_c, k, _) = weight_temp.shape
            if in_c % 16 != 0:
                weight_temp = np.concatenate(
                    [weight_temp, np.zeros((out_c, 16 - in_c % 16, k, _), dtype=weight_temp.dtype)], axis=1)
            (out_c, in_c, k, _) = weight_temp.shape
            if k == _ == 1:
                z = np.zeros([out_c, in_c, 3, 3], dtype=weight_temp.dtype)
                z[:, :, 1, 1] = weight_temp.squeeze()
                weight_temp = z
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
    def __init__(self, input_layer, out_channel: int, stride: int):
        super(ConvOrder, self).__init__()
        padding = 1  # assert padding = 1
        self.input_layer = input_layer
        self.in_shape = input_layer.out_shape
        self.stride = stride - 1
        self.parameter['stride'] = self.stride
        self.padding = padding
        self.parameter['order'] = OrderType.CONVOLUTION.value
        self.parameter['padding_size'] = padding

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
        self.using_space = self.parameter['return_patch_num'] * 4096 * np.ceil(out_channel / 8)

        self.parameter['feature_patch_num'] = input_layer.parameter['return_patch_num']
        self.parameter['fea_in_quant_size'] = input_layer.parameter['fea_out_quant_size']

    def AllocateMemory(self, memory_point_input):
        self.parameter['return_addr'] = memory_point_input
        self.allocate_memory = self.using_space // 1024
        return memory_point_input + self.using_space

    def SetInputMemory(self):
        self.parameter['feature_input_base_addr'] = self.input_layer.parameter['return_addr']

    def SetWeightAndBias(self, f_quant: int, w_quant: int, weight, bias):
        self.f_quant = f_quant
        self.w_quant = w_quant
        self.parameter['fea_out_quant_size'] = f_quant
        self.parameter['weight_quant_size'] = w_quant
        self.weight = weight
        self.bias = Quant(bias, f_quant + w_quant)


class AddOrder(Order):
    def __init__(self, inputLayerX1, inputLayerX2):
        super(AddOrder, self).__init__()
        self.inputLayerX1 = inputLayerX1
        self.inputLayerX2 = inputLayerX2
        self.parameter['order'] = OrderType.ADD.value
        self.parameter['padding_size'] = 0

        (c, w, h) = inputLayerX1.out_shape
        (self.parameter['col_size'], self.parameter['row_size']) = SplitInteger2MinimizeDifference(
            inputLayerX1.using_space // 2 // 8)
        self.parameter['feature_input_patch_num'] = 1
        self.parameter['feature_double_patch'] = 1

        self.parameter['fea_in_quant_size'] = abs(
            inputLayerX1.parameter["fea_out_quant_size"] - inputLayerX2.parameter["fea_out_quant_size"])
        self.parameter['fea_out_quant_size'] = 0 if inputLayerX1.parameter["fea_out_quant_size"] > \
                                                    inputLayerX2.parameter["fea_out_quant_size"] else 1
        self.parameter['weight_quant_size'] = 0

        self.out_shape = inputLayerX2.out_shape

        self.parameter['return_patch_num'] = inputLayerX2.parameter['return_patch_num']
        self.using_space = inputLayerX2.using_space

        self.parameter['feature_patch_num'] = inputLayerX2.parameter['return_patch_num']
        self.parameter['feature_input_base_addr'] = inputLayerX1.parameter['feature_input_base_addr']

    def AllocateMemory(self, memory_point_input):
        self.parameter['return_addr'] = self.inputLayerX2.parameter['return_addr']
        return memory_point_input


class BottleneckOrder(Order):
    def __init__(self, input_layer, out_channel: int, e: float,
                 add: bool):
        super(BottleneckOrder, self).__init__()
        self.input_layer = input_layer
        self.in_shape = input_layer.out_shape
        (c, w, h) = self.in_shape
        self.conv1 = ConvOrder(input_layer=input_layer, out_channel=int(out_channel * e), stride=1)
        self.conv2 = ConvOrder(input_layer=self.conv1, out_channel=out_channel, stride=1)
        if add:
            self.add = AddOrder(input_layer, self.conv2)
            self.ModuleList = [self.conv1, self.conv2, self.add]
            self.NameList = ['conv1', 'conv2', 'add']
        else:
            self.ModuleList = [self.conv1, self.conv2]
            self.NameList = ['conv1', 'conv2']
        self.outputLayer = self.conv2
        self.Weight = []

    def SetWeightAndBias(self, f_quant: int, w_quant: list, weight: list, bias: list):
        assert len(weight) == len(w_quant) == len(bias) == 2
        self.conv1.SetWeightAndBias(f_quant, w_quant[0], weight[0], bias[0])
        self.conv2.SetWeightAndBias(f_quant, w_quant[1], weight[1], bias[1])


class C2fOrder(Order):
    def __init__(self, input_layer, out_channel: int, n: int, add: bool = False,
                 e: float = 0.5):
        super(C2fOrder, self).__init__()
        self.input_layer = input_layer
        self.conv1 = ConvOrder(input_layer=input_layer, out_channel=int(2 * out_channel * e), stride=1)
        self.spilt = SpiltOrder(self.conv1)
        self.memcpy = MemcpyOrder(self.spilt.VirtualLayer1, self.spilt.VirtualLayer2, True)
        self.BottleList = []
        for _ in range(n):
            if _ == 0:
                self.BottleList.append(
                    BottleneckOrder(input_layer=self.spilt.VirtualLayer2, out_channel=int(2 * out_channel * e), e=1,
                                    add=add))
            else:
                self.BottleList.append(
                    BottleneckOrder(input_layer=self.BottleList[-1].outputLayer, out_channel=int(2 * out_channel * e),
                                    e=1, add=add))
        bottleListOutLayer = [bottle.outputLayer for bottle in self.BottleList]
        self.concat = ConcatOrder([self.memcpy.out_layer] + bottleListOutLayer)
        self.conv2 = ConvOrder(input_layer=self.concat, out_channel=int((2 + n) * out_channel * e), stride=1)
        self.ModuleList = [self.conv1, self.spilt] + self.BottleList + [self.concat, self.conv2]
        self.ModuleList.insert(3, self.memcpy)
        self.NameList = ['conv1', 'spilt']
        for Id, layer in enumerate(self.BottleList):
            self.NameList.append("Bottle" + str(Id))
        self.NameList.insert(3, 'memcpy')
        self.NameList += ['concat', 'conv2']
        self.outputLayer = self.ModuleList[-1]
        self.n = n
        self.Weight = []

    def SetWeightAndBias(self, f_quant: int, w_quant: list, weight: list, bias: list):
        assert len(weight) == len(w_quant) == len(bias) == 2 + self.n * 2
        self.conv1.SetWeightAndBias(f_quant=f_quant, w_quant=w_quant[0], weight=weight[0], bias=bias[0])
        for i in range(self.n):
            self.BottleList[i].SetWeightAndBias(f_quant=f_quant,
                                                w_quant=w_quant[1 + i * 2:3 + i * 2],
                                                weight=weight[1 + i * 2:3 + i * 2], bias=bias[1 + i * 2:3 + i * 2])
        self.conv2.SetWeightAndBias(f_quant=f_quant, w_quant=w_quant[-1], weight=weight[-1], bias=bias[-1])


class SPPFOrder(Order):
    def __init__(self, input_layer, out_channel: int):
        super(SPPFOrder, self).__init__()
        self.input_layer = input_layer
        self.conv1 = ConvOrder(input_layer=input_layer, out_channel=input_layer.out_shape[0] // 2, stride=1)
        # todo Maxpool
        self.conv2 = ConvOrder(input_layer=self.conv1, out_channel=out_channel, stride=1)
        self.ModuleList = [self.conv1] + [self.conv2]
        self.NameList = ['conv1', 'conv2']
        self.outputLayer = self.ModuleList[-1]
        self.Weight = []

    def SetWeightAndBias(self, f_quant: int, w_quant: list, weight: list, bias: list):
        assert len(weight) == len(w_quant) == len(bias) == 2
        self.conv1.SetWeightAndBias(f_quant=f_quant, w_quant=w_quant[0], weight=weight[0], bias=bias[0])
        self.conv2.SetWeightAndBias(f_quant=f_quant, w_quant=w_quant[-1], weight=weight[-1], bias=bias[-1])


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


class VirtualConvOrder(Order):
    def __init__(self, input_layer, index):
        super(VirtualConvOrder, self).__init__()
        self.input_layer = input_layer
        self.index = index
        (c, w, h) = input_layer.out_shape
        self.out_shape = (c // 2, w, h)
        self.using_space = input_layer.using_space // 2

    def AllocateMemory(self, memory_point_input):
        if self.index == 0:
            self.parameter['return_addr'] = self.input_layer.parameter['return_addr']
        else:
            self.parameter['return_addr'] = (self.input_layer.parameter['return_addr']
                                             + self.input_layer.using_space // 2)
        self.parameter['return_patch_num'] = self.input_layer.parameter['return_patch_num'] // 2
        return memory_point_input


class MemcpyOrder(Order):
    def __init__(self, input_layer, otherLayer=None, toOtherLayer=False):
        super(MemcpyOrder, self).__init__()
        self.toOtherLayer = toOtherLayer
        self.otherLayer = otherLayer
        self.input_layer = input_layer
        self.out_shape = input_layer.out_shape
        self.using_space = input_layer.using_space
        self.out_layer = otherLayer if self.toOtherLayer else self

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


class ConcatOrder(Order):
    def __init__(self, layerList):
        super(ConcatOrder, self).__init__()
        self.layerList = layerList
        return_patch_num = 0
        output_channel = 0
        for layer in layerList:
            return_patch_num += layer.parameter['return_patch_num']
            output_channel += layer.out_shape[0]
        self.parameter['return_patch_num'] = return_patch_num
        (c, w, h) = self.layerList[0].out_shape
        self.out_shape = (output_channel, w, h)

    def AllocateMemory(self, memory_point_input):
        self.parameter['return_addr'] = self.layerList[0].parameter['return_addr']
        return memory_point_input


class VideoImage(Order):
    def __init__(self, VideoAddr, ImageShape: tuple):
        super(VideoImage, self).__init__()
        (w, h) = ImageShape
        self.VideoAddr = VideoAddr
        self.parameter['return_patch_num'] = StandardizedStorageSpace(w, h)
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
        (conv_id, c2f_id) = (0, 0)
        self.model = {}
        inLayer = self.video
        for model in modelList:
            if model['module'] == "Conv_Q":
                name = "Conv_Q" + str(conv_id)
                conv_id += 1
                self.model[name] = ConvOrder(inLayer, model['out_channel'], model['stride'])
                self.model[name].SetWeightAndBias(7, model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name]
            elif model['module'] == "C2f_Q":
                name = "C2f_Q" + str(c2f_id)
                c2f_id += 1
                self.model[name] = C2fOrder(inLayer, model['out_channel'], model['n'], model['add'], model['e'])
                self.model[name].SetWeightAndBias(7, model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name].outputLayer
            elif model['module'] == "SPPF_Q":
                name = "SPPF_Q"
                self.model[name] = SPPFOrder(inLayer, model['out_channel'])
                self.model[name].SetWeightAndBias(7, model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name].outputLayer
            else:
                raise Exception("Error ridiculous module")
            self.weight = []
            self.bias = []
            self.weightAndBias = None

    def FlattenLayer(self, model):
        layerList = []
        layerName = []
        for name, layer in model.items():
            if layer.ModuleList is None:
                layerList.append(layer)
                layerName.append(name)
            else:
                childName, childLayer = self.GetChildLayer(layer, name)
                for i in range(len(childLayer)):
                    layerList.append(childLayer[i])
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
                flattenLayer, flattenName = reorderPosition(flattenLayer, flattenLayer[index].layerList, flattenName)
                # 删除concat层
                flattenName.remove(layer)
                flattenLayer.pop(index)
            elif "add" in layer:
                index = flattenName.index(layer)
                flattenLayer, flattenName = reorderPosition(flattenLayer, [flattenLayer[index].inputLayerX1,
                                                                           flattenLayer[index].inputLayerX2],
                                                            flattenName)
        print("Before allocate memory: {} KB".format(memory_point))
        for layer in flattenLayer:
            memory_point = layer.AllocateMemory(memory_point)
        print("After allocate memory: {} KB total allocate {} KB".format(memory_point,
                                                                         memory_point - self.FeatureSpaceAddr))

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
        for layer in flattenLayer:
            if isinstance(layer, (ConvOrder, AddOrder)):
                order.append(layer.MakeOrderString())
        with open("order.txt", 'w') as f:
            zeros_l = 64 - len(order)
            for order in order:
                f.write(order)
                f.write('\n')
            for i in range(zeros_l):
                f.write("0".zfill(256))
                f.write('\n')

    def SetWeightLength(self):
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        for layer in flattenLayer:
            layer.parameter['weight_data_length'] = 0xF74000

    def Build(self):
        self.AllocateMemory()
        self.IntParameter()
        self.PrintModelMemoryUsing()
        self.weight, self.bias = self.MakeWeight()
        self.weightAndBias = self.MakeWeightBiasBin()
        self.SetWeightLength()
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

    def CompareResult(self, memory):
        flattenName, flattenLayer = self.FlattenLayer(self.model)
        flattenName, flattenLayer = self.RemoveNoCalculateLayers(flattenName, flattenLayer)
        flattenLayer.insert(0, self.video)
        output_list = [None for _ in range(len(flattenLayer))]
        for layer in flattenLayer:
            if isinstance(layer, ConvOrder):
                simulation_data = GetConvDataFromMemory(memory, layer.out_shape, layer.parameter['return_addr'],
                                                        layer.using_space)
                input_index = flattenLayer.index(layer.input_layer)
                conv_out_ac_quant, correct, is_zero = CompareConvResult(simulation_data, output_list[input_index],
                                                                        layer.weight, layer.bias, layer.stride,
                                                                        layer.GetOutputQuant())
                output_index = flattenLayer.index(layer)
                output_list[output_index] = conv_out_ac_quant
            elif isinstance(layer, VideoImage):
                simulation_data = GetConvDataFromMemory(memory, layer.out_shape, layer.parameter['return_addr'],
                                                        layer.using_space)
                output_index = flattenLayer.index(layer)
                output_list[output_index] = simulation_data


if __name__ == '__main__':
    MyYolov8Model(0, (640, 480), 0x2000000)
