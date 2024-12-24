import numpy as np
import pickle
import torch
import cv2
from read_ddr_data import *
from compile_model import *
import os
import pickle
import copy


def Build():
    models = Yolov8MemoryChecker("./memory.npy", "./output.pkl")
    models.Build()
    with open("Yolov8_models.pkl", 'wb') as f:
        pickle.dump(models, f)
    return models


def CheckSimulationOutput():
    models = Load()
    models.refresh_simulation_data()
    models.CompareResult()
    with open("Yolov8_models.pkl", 'wb') as f:
        pickle.dump(models, f)
    return models


def Load():
    with open("Yolov8_models.pkl", 'rb') as f:
        models = pickle.load(f)
    return models


class Yolov8MemoryChecker(object):
    def __init__(self, memory_path, simulation_path):
        image, _, _ = letterbox(cv2.imread("./000000002051.jpg"))
        self.image = np.ascontiguousarray(image)
        self.memory_path = memory_path
        self.output_path = simulation_path
        if os.path.exists(memory_path):
            self.memory_data = np.load(self.memory_path).astype('int16')
        else:
            self.refresh_ddr_data()
        if os.path.exists(self.output_path):
            with open(self.output_path, 'rb') as f:
                self.output_data = pickle.load(f)
        else:
            self.refresh_simulation_data()

        self.model = MyYolov8Model(0, (640, 480), 0x2800000)

    def showImage(self):
        image = self.image
        cv2.imshow('image', image)
        cv2.waitKey(0)

    def refresh_ddr_data(self):
        self.memory_data = np.array(read_hex_file()).reshape(-1)
        np.save(self.memory_path, self.memory_data)

    def refresh_simulation_data(self):
        output_id_list, output_data = read_output_file("output.txt")
        self.output_data = {"id_list": output_id_list, "output_data": output_data}
        with open(self.output_path, 'wb') as f:
            pickle.dump(self.output_data, f)

    def Build(self):
        self.model.Build(code=True)
        image = ChangeBGR2RGB(self.image).astype(np.float32) / 255.0
        image = Quant(image, 7)
        MakePictureBin(image)

    def CompareResult(self):
        self.model.CompareResult(self.output_data['output_data'], self.output_data['id_list'])

    def PostProcessing(self):
        box, label, box_nms, label_nms = self.model.ReturnNetworkOutput()
        image = self.image.copy()
        # ShowPicture(box, label, image, "before nms")
        ShowPicture(box_nms, label_nms, image, "after nms", True)


if __name__ == '__main__':
    # model = Build()

    # model = CheckSimulationOutput()

    model = Load()
    model.PostProcessing()

    # data = np.arange(start=-8, stop=8, step=1/16, dtype=np.float32)
    # data_exp = np.exp(data)
    # data_quant = Quant(data_exp, bit=16).astype(np.uint32)
    # print("{")
    # for i in range(len(data_quant)):
    #     print(f"{data_quant[i]}, ")
    # print("};")
