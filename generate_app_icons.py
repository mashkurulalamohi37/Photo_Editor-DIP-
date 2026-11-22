import zlib
import struct
import math
import os

def create_png(width, height, pixel_fn):
    raw_rows = bytearray()
    for y in range(height):
        raw_rows.append(0)  # filter type 0 (None)
        for x in range(width):
            r, g, b, a = pixel_fn(x, y, width, height)
            raw_rows.extend([
                max(0, min(255, int(r))),
                max(0, min(255, int(g))),
                max(0, min(255, int(b))),
                max(0, min(255, int(a))),
            ])
    
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr)
    ihdr_chunk = struct.pack('>I', len(ihdr)) + b'IHDR' + ihdr + struct.pack('>I', ihdr_crc)
    
    idat_data = zlib.compress(bytes(raw_rows), 9)
    idat_crc = zlib.crc32(b'IDAT' + idat_data)
    idat_chunk = struct.pack('>I', len(idat_data)) + b'IDAT' + idat_data + struct.pack('>I', idat_crc)
    
    iend_crc = zlib.crc32(b'IEND')
    iend_chunk = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)
    
    return b'\x89PNG\r\n\x1a\n' + ihdr_chunk + idat_chunk + iend_chunk

def get_icon_pixel(x, y, w, h):
    # Normalized coordinates -1.0 to +1.0
    nx = (x + 0.5 - w / 2.0) / (w / 2.0)
    ny = (y + 0.5 - h / 2.0) / (h / 2.0)
    dist = math.sqrt(nx * nx + ny * ny)
    angle = math.atan2(ny, nx)

    # Squircle distance for icon container
    # |nx|^4 + |ny|^4 <= 1.0
    squircle_r = (abs(nx) ** 3.6 + abs(ny) ** 3.6) ** (1.0 / 3.6)
    
    if squircle_r > 0.94:
        # Anti-aliased outer edge
        edge_alpha = max(0.0, min(1.0, (1.0 - squircle_r) / 0.06))
        if edge_alpha <= 0:
            return (0, 0, 0, 0)
    else:
        edge_alpha = 1.0

    # Base background: Dark navy/slate gradient
    # Top-left to bottom-right
    bg_t = (nx + ny + 2.0) / 4.0
    r_bg = 11 + bg_t * 12
    g_bg = 15 + bg_t * 18
    b_bg = 24 + bg_t * 30

    # Outer border ring: glowing gradient between squircle_r 0.82 and 0.91
    if 0.81 <= squircle_r <= 0.93:
        border_t = (math.sin(angle * 1.5) + 1.0) * 0.5
        # Cyan (56, 189, 248) to Purple (167, 139, 250) to Emerald (52, 211, 153)
        if border_t < 0.5:
            bt2 = border_t * 2.0
            r_br = 56 + bt2 * (167 - 56)
            g_br = 189 + bt2 * (139 - 189)
            b_br = 248 + bt2 * (250 - 248)
        else:
            bt2 = (border_t - 0.5) * 2.0
            r_br = 167 + bt2 * (52 - 167)
            g_br = 139 + bt2 * (211 - 139)
            b_br = 250 + bt2 * (153 - 250)
        
        ring_intensity = math.sin((squircle_r - 0.81) / (0.93 - 0.81) * math.pi)
        r_bg = r_bg * (1 - ring_intensity * 0.8) + r_br * ring_intensity * 0.8
        g_bg = g_bg * (1 - ring_intensity * 0.8) + g_br * ring_intensity * 0.8
        b_bg = b_bg * (1 - ring_intensity * 0.8) + b_br * ring_intensity * 0.8

    # Camera Aperture Blades (circular radius between 0.35 and 0.72)
    if 0.32 <= dist <= 0.72:
        blade_angle = (angle + math.pi) % (math.pi / 3.0)  # 6 blades
        blade_phase = blade_angle / (math.pi / 3.0)
        
        # Blade seam line
        seam_dist = abs(blade_phase - 0.5)
        blade_shade = 0.85 + 0.3 * math.sin(dist * 6.0)
        
        # Aperture color: deep indigo cyan
        r_ap = 24 * blade_shade
        g_ap = 38 * blade_shade
        b_ap = 65 * blade_shade
        
        if seam_dist > 0.44:
            # Highlight border on blade edge
            r_ap += 60
            g_ap += 140
            b_ap += 180
            
        blade_blend = min(1.0, max(0.0, (dist - 0.32) / 0.05)) * min(1.0, max(0.0, (0.72 - dist) / 0.05))
        r_bg = r_bg * (1 - blade_blend) + r_ap * blade_blend
        g_bg = g_bg * (1 - blade_blend) + g_ap * blade_blend
        b_bg = b_bg * (1 - blade_blend) + b_ap * blade_blend

    # Inner Core: 3x3 Pixel Sampling Matrix (DIP digital discretization)
    if dist < 0.35:
        # Coordinates in 3x3 grid (-1.5 to 1.5)
        gx = nx / 0.105
        gy = ny / 0.105
        cell_x = math.floor(gx + 1.5)
        cell_y = math.floor(gy + 1.5)
        
        # Distance within cell
        if 0 <= cell_x <= 2 and 0 <= cell_y <= 2:
            cx = (cell_x - 1.5 + 0.5)
            cy = (cell_y - 1.5 + 0.5)
            dx = abs(gx - (cell_x - 1.0))
            dy = abs(gy - (cell_y - 1.0))
            
            # Pixel square with gap
            if dx < 0.38 and dy < 0.38:
                # Pixel intensity based on cell position (representing sampled matrix)
                # Center is brightest (white/cyan), neighbors are cyan/purple
                manhattan = abs(cell_x - 1) + abs(cell_y - 1)
                if manhattan == 0:
                    # Center sensor pixel
                    r_px, g_px, b_px = 255, 255, 255
                elif manhattan == 1:
                    # 4-neighbors (cyan)
                    r_px, g_px, b_px = 56, 189, 248
                else:
                    # Diagonal 8-neighbors (purple/indigo)
                    r_px, g_px, b_px = 167, 139, 250
                    
                # Smooth rounded pixel corners
                p_dist = max(dx, dy)
                p_blend = min(1.0, max(0.0, (0.38 - p_dist) / 0.06))
                
                r_bg = r_bg * (1 - p_blend) + r_px * p_blend
                g_bg = g_bg * (1 - p_blend) + g_px * p_blend
                b_bg = b_bg * (1 - p_blend) + b_px * p_blend

    # Subtle central laser core glow
    if dist < 0.18:
        glow = math.exp(-dist * dist * 35.0)
        r_bg = min(255, r_bg + glow * 120)
        g_bg = min(255, g_bg + glow * 200)
        b_bg = min(255, b_bg + glow * 255)

    return (int(r_bg), int(g_bg), int(b_bg), int(255 * edge_alpha))

def main():
    targets = {
        'assets/icons/app_logo.png': 512,
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    }
    
    for path, size in targets.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        print(f"Generating {path} ({size}x{size})...")
        png_bytes = create_png(size, size, get_icon_pixel)
        with open(path, 'wb') as f:
            f.write(png_bytes)
        print(f"  -> Done ({len(png_bytes)} bytes)")

if __name__ == '__main__':
    main()
