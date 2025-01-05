import numpy as np
import pickle
import torch
import cv2
from read_ddr_data import *
from compile_model import *
import os
import pickle
import copy


def Build(modelPath, videoAddr, featureSpaceAddr):
    models = Yolov8MemoryChecker("./memory.npy", "./output.pkl", modelPath, videoAddr, featureSpaceAddr)
    models.Build()
    with open("Yolov8_models.pkl", 'wb') as f:
        pickle.dump(models, f)
    return models


def CheckSimulationOutput(hard_ware=False):
    models = Load()
    if hard_ware:
        models.refresh_hardware_data()
    else:
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
    def __init__(self, memory_path, simulation_path, modelPath, videoAddr, featureSpaceAddr):
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

        self.model = MyYolov8Model(videoAddr, (640, 480), featureSpaceAddr, modelPath)

    def showImage(self):
        image = self.image
        cv2.imshow('image', image)
        cv2.waitKey(0)

    def saveImage2Bin(self):
        with open("ImageBin.bin", 'wb') as f:
            # image_c = np.zeros_like(self.image)
            (h, w, c) = self.image.shape
            # for i in range(h):
            #     for j in range(w):
            #         for k in range(c):
            #             image_c[i, j, k] = j
            f.write(np.uint16(h).tobytes())
            f.write(np.uint16(w).tobytes())
            f.write(np.uint16(c).tobytes())
            f.write(self.image.tobytes())

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
        image = ChangeBGR2RGB(self.image).astype(np.float32) / 255.0
        image = Quant(image, 7)
        MakePictureBin(image)

    def CompareResult(self):
        self.model.CompareResult(self.output_data['output_data'], self.output_data['id_list'])

    def refresh_hardware_data(self):
        filelist = os.listdir("./hardware_data")
        output_data_list = []
        id_list = []
        for file in filelist:
            with open("./hardware_data/" + file, 'rb') as f:
                data = np.frombuffer(f.read(), dtype=np.int16)
                output_data_list.append(data)
                index = int(file[:2]) - 1
                id_list.append(index)
        self.output_data = {"id_list": id_list, "output_data": output_data_list}
        with open(self.output_path, 'wb') as f:
            pickle.dump(self.output_data, f)

    def PostProcessing(self):
        box, label, box_nms, label_nms = self.model.ReturnNetworkOutput()
        image = self.image.copy()
        # ShowPicture(box, label, image, "before nms")
        ShowPicture(box_nms, label_nms, image, "after nms", True)


if __name__ == '__main__':
    # model = Build("./modelList_dirct.pkl", 0, 0x2800000)  # for simulation
    # model = Build("./modelList_dirct.pkl", 0x81000000, 0x83800000)  # for actual hardware

    # model = CheckSimulationOutput(hard_ware=True)

    model = Load()
    # model.saveImage2Bin()
    model.PostProcessing()

    # data = np.arange(start=-8, stop=8, step=1/16, dtype=np.float32)
    # data_exp = np.exp(data)
    # data_quant = Quant(data_exp, bit=16).astype(np.uint32)
    # print("{")
    # for i in range(len(data_quant)):
    #     print(f"{data_quant[i]}, ")
    # print("};")
