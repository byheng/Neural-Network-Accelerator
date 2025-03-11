import numpy as np

from read_ddr_data import *
from compile_model import *
import os
import pickle
import cv2

s_Folder = "../simulation_data"
c_Folder = "../compile_out"


def Make_picture_bin():
    image, _, _ = letterbox(cv2.imread("../yolov8/shiyanshi.jpg"))
    image = np.ascontiguousarray(image)
    image_q = Quant(image / 255.0, 7)
    MakePictureBin(image_q, c_Folder)
    return image


class GaussianFilter(Model):
    def __init__(self, VideoAddr, ImageShape: tuple, FeatureSpaceAddr):
        super(GaussianFilter, self).__init__(FeatureSpaceAddr)
        self.s_Folder = s_Folder
        self.c_Folder = c_Folder
        self.video = VideoImage(VideoAddr, ImageShape)
        self.inLayer = self.video
        self.model = {}
        inLayer = self.video
        kernel = np.zeros((3, 3, 3, 3))
        bias = np.zeros(3)
        kernel[0, 0, :, :] = [[0.05, 0.1, 0.05], [0.1, 0.4, 0.1], [0.05, 0.1, 0.05]]
        kernel[1, 1, :, :] = [[0.05, 0.1, 0.05], [0.1, 0.4, 0.1], [0.05, 0.1, 0.05]]
        kernel[2, 2, :, :] = [[0.05, 0.1, 0.05], [0.1, 0.4, 0.1], [0.05, 0.1, 0.05]]
        name = "GaussianFilter"
        self.model[name] = ConvOrder(inLayer, 3, 1, activate=False)
        kernel = Quant(kernel, 8)
        self.model[name].SetWeightAndBias(8, kernel, bias)

    def Build(self):
        self.AllocateMemory()
        self.IntParameter()
        self.PrintModelMemoryUsing()
        self.FlattenLayer(self.model, insert_name=True)
        self.weight, self.bias = self.MakeWeight()
        self.weightAndBias = self.MakeWeightBiasBin(self.c_Folder)
        self.SetWeightLength()
        self.GenerateCode(self.c_Folder)  # for axi write instruction ----> just simulation
        self.GenerateInstruction(self.c_Folder)  # for axi write instruction -----> for hardware

    def Compare(self):
        output_id_list, output_data = read_output_file(self.s_Folder + "/output.txt")
        self.CompareResult(output_data, output_id_list)

    def ShowPicture(self, image):
        filter_data = self.model['GaussianFilter'].output_data
        filter_image = deQuant(filter_data.transpose(1, 2, 0), 7)
        image = image / 255.0
        images = np.hstack([image, filter_image])
        cv2.imshow('image', images)
        cv2.waitKey(0)


class SobelFilter(Model):
    def __init__(self, VideoAddr, ImageShape: tuple, FeatureSpaceAddr):
        super(SobelFilter, self).__init__(FeatureSpaceAddr)
        self.s_Folder = s_Folder
        self.c_Folder = c_Folder
        self.video = VideoImage(VideoAddr, ImageShape)
        self.inLayer = self.video
        self.model = {}
        inLayer = self.video
        kernel = np.zeros((3, 3, 3, 3))
        bias = np.zeros(3)
        kernel[0, 0, :, :] = [[-1, 0, 1], [-3, 0, 3], [-1, 0, 1]]
        kernel[1, 1, :, :] = [[-1, 0, 1], [-3, 0, 3], [-1, 0, 1]]
        kernel[2, 2, :, :] = [[-1, 0, 1], [-3, 0, 3], [-1, 0, 1]]
        name = "SobelFilter"
        self.model[name] = ConvOrder(inLayer, 3, 1, activate=False, output_to_video=True)
        kernel = Quant(kernel, 8)
        self.model[name].SetWeightAndBias(8, kernel, bias)

    def Build(self):
        self.AllocateMemory()
        self.IntParameter()
        self.PrintModelMemoryUsing()
        self.FlattenLayer(self.model, insert_name=True)
        self.weight, self.bias = self.MakeWeight()
        self.weightAndBias = self.MakeWeightBiasBin(self.c_Folder)
        self.SetWeightLength()
        self.GenerateCode(self.c_Folder)  # for axi write instruction ----> just simulation
        self.GenerateInstruction(self.c_Folder)  # for axi write instruction -----> for hardware

    def Compare(self):
        output_id_list, output_data = read_output_file(self.s_Folder + "/output.txt")
        self.CompareResult(output_data, output_id_list)

    def ShowPicture(self, image):
        filter_data = self.model['SobelFilter'].output_data
        filter_image = deQuant(filter_data.transpose(1, 2, 0), 7)
        image = image / 255.0
        images = np.hstack([image, filter_image])
        cv2.imshow('image', images)
        cv2.waitKey(0)


if __name__ == "__main__":
    image = Make_picture_bin()
    # model = SobelFilter(0, (640, 480), 0x2800000)
    model = SobelFilter(0x81000000, (640, 480), 0x83800000)
    model.Build()
    refresh_ddr_patch(s_Folder)
    # Run_simulation()
    # model.Compare()
    # model.ShowPicture(image)
