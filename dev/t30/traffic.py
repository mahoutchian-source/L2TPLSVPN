# generates traffic on persistent tun devices: reads what the host sends (tx counter) and injects IPv4 packets (rx counter)
import fcntl, os, struct, sys, threading, time, socket
def csum(b):
    s = sum(struct.unpack("!%dH" % (len(b) // 2), b)); s = (s >> 16) + (s & 0xffff); s += s >> 16
    return ~s & 0xffff
def pkt(src, dst, n):
    pl = b"x" * n
    h = struct.pack("!BBHHHBBH4s4s", 0x45, 0, 20 + 8 + n, 1, 0, 64, 17, 0, socket.inet_aton(src), socket.inet_aton(dst))
    h = h[:10] + struct.pack("!H", csum(h)) + h[12:]
    return h + struct.pack("!HHHH", 9, 9, 8 + n, 0) + pl
def attach(dev):
    fd = os.open("/dev/net/tun", os.O_RDWR)
    fcntl.ioctl(fd, 0x400454ca, struct.pack("16sH", dev.encode(), 0x1001 | 0))
    return fd
dur = float(sys.argv[1]); links = [a.split(",") for a in sys.argv[2:]]    # dev,peer,ours,down_bytes,up_bytes
end = time.time() + dur
def reader(fd):
    while time.time() < end:
        try: os.read(fd, 4096)
        except OSError: break
fds = []
for dev, peer, ours, dn, up in links:
    fd = attach(dev); fds.append((fd, peer, ours, int(dn), int(up)))
    threading.Thread(target=reader, args=(fd,), daemon=True).start()
while time.time() < end:
    for fd, peer, ours, dn, up in fds:
        os.write(fd, pkt(peer, ours, up))                                   # arrives on the host: rx
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try: s.sendto(b"y" * dn, (peer, 9))                                 # leaves the host: tx
        except OSError: pass
        s.close()
    time.sleep(0.03 + 0.01 * (int(time.time()) % 3))
