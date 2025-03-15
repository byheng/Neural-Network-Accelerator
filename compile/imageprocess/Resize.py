import sys
sys.path.append("..")
import numpy as np
from read_ddr_data import *
from compile_model import *
import os
import pickle
import cv2
import argparse
from show_video_out import show_video_out

s_Folder = "../simulation_data"
c_Folder = "../compile_out"


def Make_picture_bin():
    image, _, _ = letterbox(cv2.imread("../yolov8/shiyanshi.jpg"))
    image = np.ascontiguousarray(image)
    image_q = Quant(image / 255.0, 7)
    MakePictureBin(image_q, c_Folder)
    return image


class Resize(Model):
    def __init__(self, VideoAddr, ImageShape: tuple, FeatureSpaceAddr):
        super(Resize, self).__init__(FeatureSpaceAddr)
        self.s_Folder = s_Folder
        self.c_Folder = c_Folder
        self.video = VideoImage(VideoAddr, ImageShape)
        self.inLayer = self.video
        self.model = {}
        inLayer = self.video
        kernel = np.zeros((3, 3, 3, 3), dtype=np.float32)
        bias = np.zeros(3)
        # 双线性插值
        kernel[0, 0, :, :] = [[1, 2, 1], [2, 4, 2], [1, 2, 1]]
        kernel[1, 1, :, :] = [[1, 2, 1], [2, 4, 2], [1, 2, 1]]
        kernel[2, 2, :, :] = [[1, 2, 1], [2, 4, 2], [1, 2, 1]]
        kernel *= (1 / 16)

        # # 双三次插值
        # kernel[0, 0, :, :] = [[-1, 0, 9], [0, 16, 0], [9, 0, -1]]
        # kernel[1, 1, :, :] = [[-1, 0, 9], [0, 16, 0], [9, 0, -1]]
        # kernel[2, 2, :, :] = [[-1, 0, 9], [0, 16, 0], [9, 0, -1]]
        # kernel *= (1 / 256)

        name = "Resize"
        self.model[name] = ConvOrder(inLayer, 3, 1.6, activate=False, output_to_video=True)
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
        filter_data = self.model['Resize'].output_data
        filter_image = deQuant(filter_data.transpose(1, 2, 0), 7)
        image = image / 255.0
        images = np.hstack([image, filter_image])
        cv2.imshow('image', images)
        cv2.waitKey(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Simulation or Build hardware code')
    parser.add_argument('--Operator', type=int, help='0 is Simulation, 1 is Build hardware code')
    args = parser.parse_args()

    if args.Operator == 0:
        image = Make_picture_bin()
        model = Resize(0, (640, 480), 0x2800000)
        model.Build()
        refresh_ddr_patch(s_Folder)
        Run_simulation(s_Folder)
        show_video_out(s_Folder)
    elif args.Operator == 1:
        # for hardware
        model = Resize(0x81000000, (640, 480), 0x83800000)  # for actual hardware
        model.Build()
