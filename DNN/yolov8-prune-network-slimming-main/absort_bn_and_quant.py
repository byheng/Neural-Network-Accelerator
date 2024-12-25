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


def best_quantization_coefficient(matrix, similarity_metric="mse"):
    """
    Find the best quantization coefficient (restricted to powers of 2 within 0-16 bits) for a matrix to maximize similarity between the
    quantized matrix and the original matrix.

    Parameters:
    matrix (np.ndarray): The input matrix.
    similarity_metric (str): The similarity metric to optimize. Options are "mse".

    Returns:
    float: The optimal quantization coefficient.
    np.ndarray: The quantized matrix using the optimal coefficient.
    """

    def quantize(mat, coeff):
        d = torch.round(mat * coeff)
        d[d >= 65536] -= 65536
        return d / coeff

    def similarity(original, quantized):
        if similarity_metric == "mse":
            d = (original - quantized) ** 2
            return torch.mean(d)
        else:
            raise ValueError("Unsupported similarity metric.")

    # Define the range of quantization coefficients as powers of 2 within 0-16 bits
    powers_of_2 = [2 ** i for i in range(0, 17)]

    best_coeff = powers_of_2[0]
    best_similarity = float('inf')

    for coeff in powers_of_2:
        quantized_matrix = quantize(matrix, coeff)
        sim = similarity(matrix, quantized_matrix)

        if sim < best_similarity:
            best_similarity = sim
            best_coeff = coeff

    # Return the best quantized matrix with the optimal coefficient
    final_quantized_matrix = quantize(matrix, best_coeff)
    return best_coeff, final_quantized_matrix


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
        w_bit, weight_q = best_quantization_coefficient(w)
        conv.bias = nn.Parameter(b)
        conv.weight = nn.Parameter(w)
        setattr(conv, "w_bit", w_bit)
        setattr(conv, "weight_q", weight_q)

        return conv


def fuse_quant_model(model):
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


if __name__ == '__main__':
    model = YOLO('./runs/detect/640-relu-35/weights/best.pt')
    model_dict = model.model.model
    model_dict.float()
    fuse_model = fuse_quant_model(model_dict)
    model.model.model = fuse_model
