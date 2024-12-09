import time

import numpy as np


def back_double(strs):
    hex_values = [int(strs[i:i + 4], 16) for i in range(0, len(strs), 4)]
    hex_values = hex_values[::-1]
    return np.array(hex_values).astype(np.int16)

def read_hex_file():
    with open('memory_patch.txt', 'r') as file:
        lines = file.readlines()
        memory = []
        for line in lines:
            # 去除换行符，分割每行的两个十六进制数，并转换为整数
            if line[0] == "/":
                continue
            else:
                hex_values = line.strip()
                memory.append(back_double(hex_values))
        return memory


if __name__ == '__main__':
    t = time.time_ns()
    data = read_hex_file()
    np.save('memory.npy', np.array(data).reshape(-1))
    print((time.time_ns() - t) / 1000000)
