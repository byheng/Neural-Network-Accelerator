import torch
from ultralytics import YOLO
from ultralytics.nn.modules import *
from ultralytics.nn.quant_dorefa import input_dict, output_dict
import pickle


def CalculateWeightsScale(weight, w_bit):
    max_w = torch.max(torch.abs(weight)).detach()
    scale = (2 ** (w_bit - 1) - 1) / max_w
    scale = 2 ** torch.floor(torch.log2(scale))
    weight_q = torch.round(scale * weight).detach().cpu().numpy()
    scale = torch.log2(scale).detach().cpu().numpy()
    return scale, weight_q


model = YOLO('./runs/detect/640-16bit-onlyweight/weights/best.pt')
# model_dict = list(model.model.model)
#
# modelList = []
# for layer in model_dict:
#     if isinstance(layer, Conv_Q):
#         newLayerDict = {'module': "Conv_Q", 'actFuc': layer.act.__class__.__name__}
#         (newLayerDict['scale'], newLayerDict['quantWeight']) = CalculateWeightsScale(layer.conv.weight, layer.conv.w_bit)
#         newLayerDict['bias'] = layer.conv.bias.detach().cpu().numpy()
#         newLayerDict['out_channel'] = layer.conv.out_channels
#         newLayerDict['stride'] = layer.conv.stride[0]
#         modelList.append(newLayerDict)
#     elif isinstance(layer, C2f_Q):
#         newLayerDict = {'module': "C2f_Q"}
#         weight_list = []
#         bias_list = []
#         weight_scale = []
#         scale, weight = CalculateWeightsScale(layer.cv1.conv.weight, layer.cv1.conv.w_bit)
#         bias = layer.cv1.conv.bias.detach().cpu().numpy()
#         weight_list.append(weight)
#         bias_list.append(bias)
#         weight_scale.append(scale)
#         newLayerDict['n'] = len(layer.m)
#         for bottle in layer.m:
#             scale, weight = CalculateWeightsScale(bottle.cv1.conv.weight, bottle.cv1.conv.w_bit)
#             bias = bottle.cv1.conv.bias.detach().cpu().numpy()
#             weight_list.append(weight)
#             weight_scale.append(scale)
#             bias_list.append(bias)
#             scale, weight = CalculateWeightsScale(bottle.cv2.conv.weight, bottle.cv2.conv.w_bit)
#             bias = bottle.cv2.conv.bias.detach().cpu().numpy()
#             weight_list.append(weight)
#             weight_scale.append(scale)
#             bias_list.append(bias)
#         scale, weight = CalculateWeightsScale(layer.cv2.conv.weight, layer.cv2.conv.w_bit)
#         bias = layer.cv2.conv.bias.detach().cpu().numpy()
#         weight_list.append(weight)
#         bias_list.append(bias)
#         weight_scale.append(scale)
#         newLayerDict['add'] = layer.m[0].add
#         newLayerDict['out_channel'] = layer.cv2.conv.out_channels
#         newLayerDict['e'] = layer.c / newLayerDict['out_channel']
#         newLayerDict['quantWeight'] = weight_list
#         newLayerDict['scale'] = weight_scale
#         newLayerDict['bias'] = bias_list
#         modelList.append(newLayerDict)
#     elif isinstance(layer, SPPF_Q):
#         newLayerDict = {'module': "SPPF_Q"}
#         weight_list = []
#         bias_list = []
#         weight_scale = []
#         scale, weight = CalculateWeightsScale(layer.cv1.conv.weight, layer.cv1.conv.w_bit)
#         bias = layer.cv1.conv.bias.detach().cpu().numpy()
#         weight_list.append(weight)
#         weight_scale.append(scale)
#         bias_list.append(bias)
#         scale, weight = CalculateWeightsScale(layer.cv2.conv.weight, layer.cv2.conv.w_bit)
#         bias = layer.cv2.conv.bias.detach().cpu().numpy()
#         weight_list.append(weight)
#         weight_scale.append(scale)
#         bias_list.append(bias)
#         newLayerDict['quantWeight'] = weight_list
#         newLayerDict['bias'] = bias_list
#         newLayerDict['scale'] = weight_scale
#         newLayerDict['out_channel'] = layer.cv2.conv.out_channels
#         modelList.append(newLayerDict)
#
# with open('modelList.pkl', 'wb') as f:
#     pickle.dump(modelList, f)

results = model.predict("/home/hipeson/hzq/ultralytics2/datasets/coco/images/test2017/000000000063.jpg",
                        save=True, device=0)
with open('input_list.pkl', 'wb') as file:
    pickle.dump(input_dict, file)
with open('output_list.pkl', 'wb') as file:
    pickle.dump(output_dict, file)
