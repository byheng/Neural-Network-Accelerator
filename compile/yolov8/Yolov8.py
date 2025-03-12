import sys
sys.path.append("..")
import numpy as np
import pickle
import torch
import cv2
from read_ddr_data import *
from compile_model import *
import os
import pickle
import copy
import argparse

s_Folder = "../simulation_data"
c_Folder = "../compile_out"


class MyYolov8Model(Model):
    def __init__(self, VideoAddr, ImageShape: tuple, FeatureSpaceAddr, modelPath, s_Folder, c_Folder):
        super(MyYolov8Model, self).__init__(FeatureSpaceAddr)
        self.s_Folder = s_Folder
        self.c_Folder = c_Folder
        self.video = VideoImage(VideoAddr, ImageShape)
        self.inLayer = self.video
        modelList = pickle.load(open(modelPath, 'rb'))
        (conv_id, c2f_id, upsample_id, concat_id) = (0, 0, 0, 0)
        self.model = {}
        inLayer = self.video
        for model in modelList:
            if model['module'] == "Conv_Q":
                name = "Conv_Q" + str(conv_id)
                conv_id += 1
                self.model[name] = ConvOrder(inLayer, model['out_channel'], model['stride'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name]
            elif model['module'] == "C2f_Q":
                name = "C2f_Q" + str(c2f_id)
                c2f_id += 1
                self.model[name] = C2fOrder(inLayer, model['out_channel'], model['n'], model['add'], model['e'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name].outputLayer
            elif model['module'] == "SPPF_Q":
                name = "SPPF_Q"
                self.model[name] = SPPFOrder(inLayer, model['out_channel'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
                inLayer = self.model[name].outputLayer
            elif model['module'] == "UPSAMPLE":
                name = "UPSAMPLE" + str(upsample_id)
                upsample_id += 1
                self.model[name] = UpsampleOrder(inLayer)
                inLayer = self.model[name]
            elif model['module'] == "CONCAT":
                name = "concat" + str(concat_id)
                concat_id += 1
                layer_list = []
                for i in model['layer_list']:
                    key = list(self.model.keys())
                    layer = self.model[key[i]]
                    layer_list.append(layer.outputLayer if hasattr(layer, 'outputLayer') else layer)
                self.model[name] = ConcatOrder(layer_list)
                inLayer = self.model[name]
            elif model['module'] == "DETECT_Q":
                name = "DETECT_Q"
                layer_list = []
                for i in model['layer_list']:
                    key = list(self.model.keys())
                    layer = self.model[key[i]]
                    layer_list.append(layer.outputLayer if hasattr(layer, 'outputLayer') else layer)
                self.model[name] = DetectOrder(layer_list, model['reg_max'], model['class'])
                self.model[name].SetWeightAndBias(model['scale'], model['quantWeight'], model['bias'])
            else:
                raise Exception("Error ridiculous module")

    def Build(self):
        self.AllocateMemory()
        self.IntParameter()
        self.FlattenLayer(self.model, insert_name=True)
        self.weight, self.bias = self.MakeWeight()
        self.weightAndBias = self.MakeWeightBiasBin(self.c_Folder)
        self.SetWeightLength()
        self.GenerateCode(self.c_Folder)  # for axi write instruction ----> just simulation
        self.GenerateInstruction(self.c_Folder)  # for axi write instruction -----> for hardware
        self.GenerateVisualInstruction(self.c_Folder)
        self.PrintModelMemoryUsing()

    def ReturnNetworkOutput(self):
        box = []
        cls = []
        Csum = []
        for i in range(3):
            cv2_out = deQuant(self.model['DETECT_Q'].cv2[3 * i + 2].output_data, 7)
            cv3_out = deQuant(self.model['DETECT_Q'].cv3[3 * i + 2].output_data - 178, 7)
            s = deQuant(self.model['DETECT_Q'].ModuleList[-3+i].ModuleList[0].output_data.reshape(1, -1), 7)
            box.append(cv2_out)
            cls.append(cv3_out)
            Csum.append(s)
        anchor, stride, box, cls = MakeAnchors(box, cls)
        box = np.concatenate(box, axis=1)
        cls = np.concatenate(cls, axis=1)
        Csum = np.concatenate(Csum, axis=1)

        box_valid, cls_valid, anchor_valid, stride_valid = SelectValidBox(box, cls, anchor, stride, Csum)
        box_list = DFL(box_valid, self.model['DETECT_Q'].reg_max, anchor_valid, stride_valid)
        label = np.argmax(cls_valid, axis=0)
        box_nms = []
        label_nms = []
        for i in range(self.model['DETECT_Q'].c3):
            select = label == i
            box_remain = NonMaximumSuppression(box_list[select, :], cls_valid[i, select], 0.5)
            box_nms += box_remain
            label_nms += [i for j in range(len(box_remain))]
        box_nms = np.stack(box_nms, axis=0)
        label_nms = np.stack(label_nms, axis=0)
        return box_list, label, box_nms, label_nms


def Build(modelPath, videoAddr, featureSpaceAddr):
    models = Yolov8MemoryChecker(s_Folder + "/memory.npy", s_Folder + "/output.pkl", modelPath, videoAddr, featureSpaceAddr)
    models.Build()
    with open("Yolov8_models.pkl", 'wb') as f:
        pickle.dump(models, f)
    return models


def CheckSimulationOutput(models, hard_ware=False):
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
        self.s_Folder = s_Folder
        self.c_Folder = c_Folder
        image, _, _ = letterbox(cv2.imread("shiyanshi.jpg"))
        self.image = np.ascontiguousarray(image)
        self.memory_path = memory_path
        self.output_path = simulation_path
        self.model = MyYolov8Model(videoAddr, (640, 480), featureSpaceAddr, modelPath, s_Folder, c_Folder)

    def showImage(self):
        image = self.image
        cv2.imshow('image', image)
        cv2.waitKey(0)

    def saveImage2Bin(self):
        with open("ImageBin.bin", 'wb') as f:
            (h, w, c) = self.image.shape
            f.write(np.uint16(h).tobytes())
            f.write(np.uint16(w).tobytes())
            f.write(np.uint16(c).tobytes())
            f.write(self.image.tobytes())

    def refresh_simulation_data(self):
        output_id_list, output_data = read_output_file(self.s_Folder + "/output.txt")
        self.output_data = {"id_list": output_id_list, "output_data": output_data}
        with open(self.output_path, 'wb') as f:
            pickle.dump(self.output_data, f)

    def Build(self):
        self.model.Build()
        image = ChangeBGR2RGB(self.image).astype(np.float32) / 255.0
        image = Quant(image, 7)
        MakePictureBin(image, self.c_Folder)

    def CompareResult(self):
        self.model.CompareResult(self.output_data['output_data'], self.output_data['id_list'])

    def refresh_hardware_data(self):
        filelist = os.listdir("../hardware_data")
        output_data_list = []
        id_list = []
        for file in filelist:
            with open("../hardware_data/" + file, 'rb') as f:
                data = np.frombuffer(f.read(), dtype=np.int16)
                output_data_list.append(data)
                index = int(file[:2]) - 1
                id_list.append(index)
        self.output_data = {"id_list": id_list, "output_data": output_data_list}
        with open(self.output_path, 'wb') as f:
            pickle.dump(self.output_data, f)

    def PostProcessing(self):
        box, label, box_nms, label_nms = self.model.ReturnNetworkOutput()
        box_nms = np.array(box_nms)
        label_nms = np.array(label_nms)
        image = self.image.copy()
        ShowPicture(box_nms, label_nms, image, "after nms", True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Simulation or Build hardware code')
    parser.add_argument('--Operator', type=int, help='0 is Simulation, 1 is Build hardware code')
    args = parser.parse_args()

    if args.Operator == 0:
        model = Build("./modelList_dirct.pkl", 0, 0x2800000)  # for simulation
        refresh_ddr_patch(s_Folder)
        Run_simulation(s_Folder)
        model = CheckSimulationOutput(model, hard_ware=False)
        model.PostProcessing()
    elif args.Operator == 1:
        # for hardware
        model = Build("./modelList_dirct.pkl", 0x81000000, 0x83800000)  # for actual hardware
