import numpy as np
from read_ddr_data import back_double
import cv2


def read_video(video_file, size):
    h, w, c = size
    image = np.ones(size, dtype=np.uint8) * 255
    row = 0
    col = 0
    with open(video_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line == "enter":
                row += 1
                if col != w:
                    print("error")
                col = 0
            else:
                data = back_double(line, 2)
                image[row, col, :] = data
                col += 1
    if row != h:
        print("error, h = %d, w = %d", row, col)
    return image


if __name__ == '__main__':
    image = read_video('./simulation_data/video.txt', (480, 640, 4))
    image = image[:, :, :3]
    image = image[:, :, ::-1]
    cv2.imshow("image", image)
    cv2.waitKey(0)
