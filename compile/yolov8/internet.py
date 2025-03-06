import socket
import numpy as np
import cv2
import threading

UDP_IP = "192.168.1.10"
UDP_PORT = 8080
BUFFER_SIZE = 640*480*3

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))

data_buffer = np.zeros(BUFFER_SIZE)
running = True  # 线程控制变量

def receive_data():
    global data_buffer
    while running:
        try:
            data, addr = sock.recvfrom(BUFFER_SIZE)
            print(f"Received {len(data)} bytes from {addr}")

            if data.startswith(b"START"):
                data_buffer = b""
            elif data.startswith(b"END"):
                np_arr = np.frombuffer(data_buffer, dtype=np.uint8)
                img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
                if img is not None:
                    cv2.imshow("Received Image", img)
                    cv2.waitKey(1)
                else:
                    print("Failed to decode image")
            else:
                data_buffer += data
        except socket.error:
            pass  # 忽略错误继续循环

# 启动UDP监听线程
udp_thread = threading.Thread(target=receive_data, daemon=True)
udp_thread.start()

# 主线程可以执行其他任务
try:
    while True:
        pass  # 这里可以做其他事情
except KeyboardInterrupt:
    running = False
    udp_thread.join()
    print("Receiver stopped.")
