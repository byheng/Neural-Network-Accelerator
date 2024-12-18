import numpy as np
import pickle
import torch
import cv2
from read_ddr_data import *
from compile_model import *
import os
import pickle


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
        with open('input_list.pkl', 'rb') as f:
            self.input_list = pickle.load(f)[63:]
        with open('output_list.pkl', 'rb') as f:
            self.output_list = pickle.load(f)[63:0]
        self.image = self.input_list[0].detach().cpu().numpy()
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

    def fixImage(self):
        image = deQuant(self.image, 7).squeeze().transpose(1, 2, 0)
        temp = image[:, :, 2]
        image[:, :, 2] = image[:, :, 0]
        image[:, :, 0] = temp
        return image

    def showImage(self):
        image = self.fixImage()
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
        self.model.Build()
        MakePictureBin(self.image)

    def CompareResult(self):
        self.model.CompareResult(self.output_data['output_data'], self.output_data['id_list'])

    def PostProcessing(self):
        box, label, box_nms, label_nms = self.model.ReturnNetworkOutput()
        image = self.fixImage()
        # ShowPicture(box, label, image, "before nms")
        ShowPicture(box_nms, label_nms, image, "after nms", True)


if __name__ == '__main__':
    # model = Build()

    # model = CheckSimulationOutput()

    model = Load()
    # model.showImage()
    model.PostProcessing()
