import argparse
import time
from pathlib import Path

import cv2
import torch
import torch.nn as nn
import torch.backends.cudnn as cudnn
from numpy import random
from ultralytics import YOLO
import numpy as np
import torch
import torch.nn as nn
from ultralytics.nn.modules import (
    SPPF,
    Bottleneck,
    Conv,
    C2f
)


def fuse_conv_and_bn(conv, bn):
    with torch.no_grad():
        w = conv.weight
        mean = bn.running_mean
        var_sqrt = torch.sqrt(bn.running_var + bn.eps)
        beta = bn.weight
        gamma = bn.bias
        if conv.bias is not None:
            b = conv.bias
        else:
            b = mean.new_zeros(mean.shape)
        w = w * (beta / var_sqrt).reshape([conv.out_channels, 1, 1, 1])
        b = (b - mean) / var_sqrt * beta + gamma

        conv.bias = nn.Parameter(b)
        conv.weight = nn.Parameter(w)

        return conv


def fuse_model(model):
    for m in model.modules():
        if isinstance(m, torch.nn.Sequential):
            for idx in range(len(m)):
                if isinstance(m[idx], Conv):
                    fused_conv = fuse_conv_and_bn(m[idx].conv, m[idx].bn)
                    m[idx].conv = fused_conv
                    m[idx].bn = nn.Identity()

                elif isinstance(m[idx], C2f):
                    fused_conv = fuse_conv_and_bn(m[idx].cv1.conv, m[idx].cv1.bn)
                    m[idx].cv1.conv = fused_conv
                    m[idx].cv1.bn = nn.Identity()

                    bottle_neck_list = m[idx].m
                    for bottle_neck in bottle_neck_list:
                        fused_conv1 = fuse_conv_and_bn(bottle_neck.cv1.conv, bottle_neck.cv1.bn)
                        fused_conv2 = fuse_conv_and_bn(bottle_neck.cv2.conv, bottle_neck.cv2.bn)
                        bottle_neck.cv1.conv = fused_conv1
                        bottle_neck.cv1.bn = nn.Identity()
                        bottle_neck.cv2.conv = fused_conv2
                        bottle_neck.cv2.bn = nn.Identity()

                    fused_conv = fuse_conv_and_bn(m[idx].cv2.conv, m[idx].cv2.bn)
                    m[idx].cv2.conv = fused_conv
                    m[idx].cv2.bn = nn.Identity()

                elif isinstance(m[idx], Bottleneck):
                    fused_conv1 = fuse_conv_and_bn(m[idx].cv1.conv, m[idx].cv1.bn)
                    fused_conv2 = fuse_conv_and_bn(m[idx].cv2.conv, m[idx].cv2.bn)
                    m[idx].cv1.conv = fused_conv1
                    m[idx].cv1.bn = nn.Identity()
                    m[idx].cv2.conv = fused_conv2
                    m[idx].cv2.bn = nn.Identity()

                elif isinstance(m[idx], SPPF):
                    fused_conv1 = fuse_conv_and_bn(m[idx].cv1.conv, m[idx].cv1.bn)
                    fused_conv2 = fuse_conv_and_bn(m[idx].cv2.conv, m[idx].cv2.bn)
                    m[idx].cv1.conv = fused_conv1
                    m[idx].cv1.bn = nn.Identity()
                    m[idx].cv2.conv = fused_conv2
                    m[idx].cv2.bn = nn.Identity()

    return model


def change_model2model_q(yaml_page):
    yaml_page['yaml_file'] = 'ultralytics/cfg/models/v8/yolov8_q.yaml'
    model_patch = ["head", "backbone"]
    for key in model_patch:
        model_list = yaml_page[key]
        for i, layer_list in enumerate(model_list):
            for j, s in enumerate(layer_list):
                if s in ['Conv', 'Bottleneck', 'SPPF', 'Detect', 'C2f']:
                    layer_list[j] = s + '_Q'
            model_list[i] = layer_list
        yaml_page[key] = model_list

    return yaml_page


if __name__ == '__main__':
    weights = './ultralytics/weights/yolov8n.pt'
    model = torch.load(weights)
    model['train_args']['data'] = './ultralytics/cfg/datasets/coco.yaml'
    model_list = model['model']
    model_list.yaml = change_model2model_q(model_list.yaml)
    model_list.float()
    fused_model = fuse_model(model_list)
    model['model'] = fused_model
    torch.save(model, './ultralytics/weights/yolov8-fuse.pt')

    print('...')
