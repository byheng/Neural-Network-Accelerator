import torch
from torch import nn
from ultralytics import YOLO
from ultralytics.nn.modules import *
from ultralytics.nn.quant_dorefa import input_dict, output_dict
import pickle
from ultralytics.nn.modules import (
    SPPF,
    Bottleneck,
    Bottleneck_Q,
    Conv,
    Conv_Q,
    Conv2d_Q,
    C2f,
    Concat,
    Detect_Q
)
from torch.nn import Upsample

def CalculateWeightsScale(w):
    return None, None

model = YOLO('./runs/detect/640-relu-35/weights/best.pt')
model_dict = list(model.model.model)
modelList = []
for layer in model_dict:
    if isinstance(layer, Conv_Q):
        newLayerDict = {'module': "Conv_Q", 'actFuc': layer.act.__class__.__name__}
        (newLayerDict['scale'], newLayerDict['quantWeight']) = CalculateWeightsScale(layer.conv.weight)
        newLayerDict['bias'] = layer.conv.bias.detach().cpu().numpy()
        newLayerDict['out_channel'] = layer.conv.out_channels
        newLayerDict['stride'] = layer.conv.stride[0]
        modelList.append(newLayerDict)
    elif isinstance(layer, C2f_Q):
        newLayerDict = {'module': "C2f_Q"}
        weight_list = []
        bias_list = []
        weight_scale = []
        scale, weight = CalculateWeightsScale(layer.cv1.conv.weight)
        bias = layer.cv1.conv.bias.detach().cpu().numpy()
        weight_list.append(weight)
        bias_list.append(bias)
        weight_scale.append(scale)
        newLayerDict['n'] = len(layer.m)
        for bottle in layer.m:
            scale, weight = CalculateWeightsScale(bottle.cv1.conv.weight)
            bias = bottle.cv1.conv.bias.detach().cpu().numpy()
            weight_list.append(weight)
            weight_scale.append(scale)
            bias_list.append(bias)
            scale, weight = CalculateWeightsScale(bottle.cv2.conv.weight)
            bias = bottle.cv2.conv.bias.detach().cpu().numpy()
            weight_list.append(weight)
            weight_scale.append(scale)
            bias_list.append(bias)
        scale, weight = CalculateWeightsScale(layer.cv2.conv.weight)
        bias = layer.cv2.conv.bias.detach().cpu().numpy()
        weight_list.append(weight)
        bias_list.append(bias)
        weight_scale.append(scale)
        newLayerDict['add'] = layer.m[0].add
        newLayerDict['out_channel'] = layer.cv2.conv.out_channels
        newLayerDict['e'] = layer.c / newLayerDict['out_channel']
        newLayerDict['quantWeight'] = weight_list
        newLayerDict['scale'] = weight_scale
        newLayerDict['bias'] = bias_list
        modelList.append(newLayerDict)
    elif isinstance(layer, SPPF_Q):
        newLayerDict = {'module': "SPPF_Q"}
        weight_list = []
        bias_list = []
        weight_scale = []
        scale, weight = CalculateWeightsScale(layer.cv1.conv.weight)
        bias = layer.cv1.conv.bias.detach().cpu().numpy()
        weight_list.append(weight)
        weight_scale.append(scale)
        bias_list.append(bias)
        scale, weight = CalculateWeightsScale(layer.cv2.conv.weight)
        bias = layer.cv2.conv.bias.detach().cpu().numpy()
        weight_list.append(weight)
        weight_scale.append(scale)
        bias_list.append(bias)
        newLayerDict['quantWeight'] = weight_list
        newLayerDict['bias'] = bias_list
        newLayerDict['scale'] = weight_scale
        newLayerDict['out_channel'] = layer.cv2.conv.out_channels
        modelList.append(newLayerDict)
    elif isinstance(layer, Upsample):
        newLayerDict = {'module': "UPSAMPLE"}
        modelList.append(newLayerDict)
    elif isinstance(layer, Concat):
        newLayerDict = {'module': "CONCAT",
                        'layer_list': layer.f}
        modelList.append(newLayerDict)
    elif isinstance(layer, Detect_Q):
        newLayerDict = {'module': "DETECT_Q",
                        'layer_list': layer.f}
        weight_list = []
        bias_list = []
        weight_scale = []
        for i in range(3):
            for j in range(3):
                ll = layer.cv2[i][j].conv if hasattr(layer.cv2[i][j], "conv") else layer.cv2[i][j]
                scale, weight = CalculateWeightsScale(ll.weight)
                bias = ll.bias.detach().cpu().numpy()
                weight_list.append(weight)
                weight_scale.append(scale)
                bias_list.append(bias)
        for i in range(3):
            for j in range(3):
                ll = layer.cv3[i][j].conv if hasattr(layer.cv3[i][j], "conv") else layer.cv3[i][j]
                scale, weight = CalculateWeightsScale(ll.weight)
                bias = ll.bias.detach().cpu().numpy()
                weight_list.append(weight)
                weight_scale.append(scale)
                bias_list.append(bias)
        newLayerDict['quantWeight'] = weight_list
        newLayerDict['bias'] = bias_list
        newLayerDict['scale'] = weight_scale
        newLayerDict['reg_max'] = layer.reg_max
        newLayerDict['class'] = layer.nc
        modelList.append(newLayerDict)

with open('modelList.pkl', 'wb') as f:
    pickle.dump(modelList, f)
