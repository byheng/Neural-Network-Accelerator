import numpy as np
import pickle
import torch
import cv2
from read_ddr_data import *
from compile_model import *
import os


class Yolov8MemoryChecker(object):
    def __init__(self, memory_path):
        with open('input_list.pkl', 'rb') as f:
            self.input_list = pickle.load(f)[63:]
        with open('output_list.pkl', 'rb') as f:
            self.output_list = pickle.load(f)[63:0]
        self.image = self.input_list[0].detach().cpu().numpy()
        self.memory_path = memory_path
        if os.path.exists(memory_path):
            self.memory_data = np.load(self.memory_path).astype('int16')
        else:
            self.refresh_ddr_data()
        self.model = MyYolov8Model(0, (640, 480), 0x2000000)

    def showImage(self):
        image = deQuant(self.image, 7).squeeze().transpose(1, 2, 0)
        temp = image[:, :, 2]
        image[:, :, 2] = image[:, :, 0]
        image[:, :, 0] = temp
        cv2.imshow('image', image)
        cv2.waitKey(0)

    def refresh_ddr_data(self):
        self.memory_data = np.array(read_hex_file()).reshape(-1)
        np.save(self.memory_path, self.memory_data)

    def Build(self):
        self.model.Build()
        image = np.zeros_like(self.image)
        [_, c, w, h] = image.shape
        for i in range(h):
            image[:, :, :, i] = i + 1
        MakePictureBin(image)

    def CompareResult(self):
        self.model.CompareResult(self.memory_data)


if __name__ == '__main__':
    model = Yolov8MemoryChecker("./memory.npy")
    model.Build()
    # model.refresh_ddr_data()
    # model.showImage()
    model.CompareResult()
