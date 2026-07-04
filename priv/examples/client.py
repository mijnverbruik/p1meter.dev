import socket

sock = socket.create_connection(("p1meter.dev", 8080))
print("Connected to Smart Meter P1 Stream")

try:
    while data := sock.recv(4096):
        # Raw telegram data (DSMR 5.0 format)
        print(data.decode(), end="")
finally:
    sock.close()
    print("Connection closed")
