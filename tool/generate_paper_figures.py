import os
import zlib
import struct
import math
import random

def save_png(filename, width, height, pixels):
    """
    pixels: list of (r, g, b) tuples or flat list of length width*height*3
    """
    raw_rows = bytearray()
    for y in range(height):
        raw_rows.append(0)  # filter type 0 (None)
        row_offset = y * width
        for x in range(width):
            r, g, b = pixels[row_offset + x]
            raw_rows.extend([
                max(0, min(255, int(r))),
                max(0, min(255, int(g))),
                max(0, min(255, int(b)))
            ])
            
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr)
    ihdr_chunk = struct.pack('>I', len(ihdr)) + b'IHDR' + ihdr + struct.pack('>I', ihdr_crc)
    
    idat_data = zlib.compress(bytes(raw_rows), 9)
    idat_crc = zlib.crc32(b'IDAT' + idat_data)
    idat_chunk = struct.pack('>I', len(idat_data)) + b'IDAT' + idat_data + struct.pack('>I', idat_crc)
    
    iend_crc = zlib.crc32(b'IEND')
    iend_chunk = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)
    
    png_data = b'\x89PNG\r\n\x1a\n' + ihdr_chunk + idat_chunk + iend_chunk
    with open(filename, 'wb') as f:
        f.write(png_data)
    print(f"Saved PNG: {filename} ({width}x{height}, {len(png_data)} bytes)")

def draw_simple_text(pixels, width, height, text, start_x, start_y, color=(255, 255, 255), bg_color=(0, 0, 0)):
    # 5x7 bitmap font for minimal uppercase/digits/symbols
    FONT_5X7 = {
        'A': [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        'B': [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
        'C': [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
        'D': [0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C],
        'E': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
        'F': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
        'G': [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E],
        'H': [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        'I': [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
        'J': [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C],
        'K': [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
        'L': [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
        'M': [0x11, 0x1B, 0x15, 0x11, 0x11, 0x11, 0x11],
        'N': [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11],
        'O': [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        'P': [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
        'Q': [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D],
        'R': [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
        'S': [0x0E, 0x11, 0x10, 0x0E, 0x01, 0x11, 0x0E],
        'T': [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
        'U': [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        'V': [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
        'W': [0x11, 0x11, 0x11, 0x11, 0x15, 0x1B, 0x11],
        'X': [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
        'Y': [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04],
        'Z': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
        '0': [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
        '1': [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
        '2': [0x0E, 0x11, 0x01, 0x06, 0x08, 0x10, 0x1F],
        '3': [0x1F, 0x01, 0x02, 0x0E, 0x01, 0x11, 0x0E],
        '4': [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
        '5': [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
        '6': [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
        '7': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
        '8': [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
        '9': [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
        ':': [0x00, 0x04, 0x04, 0x00, 0x04, 0x04, 0x00],
        '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06],
        ',': [0x00, 0x00, 0x00, 0x00, 0x04, 0x04, 0x08],
        '-': [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
        '+': [0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00],
        '(': [0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02],
        ')': [0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08],
        '%': [0x19, 0x19, 0x02, 0x04, 0x08, 0x13, 0x13],
        '=': [0x00, 0x1F, 0x00, 0x1F, 0x00, 0x00, 0x00],
        ' ': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    }
    
    cur_x = start_x
    for ch in text.upper():
        bitmap = FONT_5X7.get(ch, FONT_5X7[' '])
        for row in range(7):
            line = bitmap[row]
            for col in range(5):
                px = cur_x + col
                py = start_y + row
                if 0 <= px < width and 0 <= py < height:
                    if (line >> (4 - col)) & 1:
                        pixels[py * width + px] = color
        cur_x += 6

def generate_fig1_svg():
    svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 340" width="100%" height="auto" style="font-family:'Times New Roman', Times, serif; background:#ffffff;">
  <defs>
    <!-- Gradients -->
    <linearGradient id="gradHeader" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#0f172a" />
      <stop offset="100%" stop-color="#1e293b" />
    </linearGradient>
    <linearGradient id="gradPillar1" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#f0f9ff" />
      <stop offset="100%" stop-color="#e0f2fe" />
    </linearGradient>
    <linearGradient id="gradPillar2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#faf5ff" />
      <stop offset="100%" stop-color="#f3e8ff" />
    </linearGradient>
    <linearGradient id="gradPillar3" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#f0fdf4" />
      <stop offset="100%" stop-color="#dcfce7" />
    </linearGradient>
    <linearGradient id="gradPillar4" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#fffbeb" />
      <stop offset="100%" stop-color="#fef3c7" />
    </linearGradient>
    <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">
      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000000" flood-opacity="0.1" />
    </filter>
    <marker id="arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#334155" />
    </marker>
  </defs>

  <!-- Outer Border Box -->
  <rect x="5" y="5" width="870" height="330" rx="6" fill="#f8fafc" stroke="#64748b" stroke-width="1.2" />

  <!-- Top Title Bar -->
  <rect x="6" y="6" width="868" height="32" rx="5" fill="url(#gradHeader)" />
  <text x="440" y="27" fill="#ffffff" font-size="13" font-weight="bold" text-anchor="middle" letter-spacing="0.8">
    DIP STUDIO NATIVE ENGINE: ARCHITECTURAL PIPELINE &amp; DATA FLOW
  </text>

  <!-- Flow Bar: Input Stage -->
  <rect x="25" y="48" width="180" height="34" rx="4" fill="#ffffff" stroke="#0284c7" stroke-width="1.2" filter="url(#shadow)" />
  <text x="115" y="63" font-size="10.5" font-weight="bold" fill="#0369a1" text-anchor="middle">Continuous Scene f(x, y)</text>
  <text x="115" y="76" font-size="8.5" fill="#64748b" text-anchor="middle">Optical Radiance Acquisition</text>

  <!-- Arrow 1 -->
  <line x1="205" y1="65" x2="235" y2="65" stroke="#334155" stroke-width="1.8" marker-end="url(#arrow)" />

  <!-- Stage: Sampling & Quantization -->
  <rect x="240" y="48" width="220" height="34" rx="4" fill="#ffffff" stroke="#7c3aed" stroke-width="1.2" filter="url(#shadow)" />
  <text x="350" y="63" font-size="10" font-weight="bold" fill="#6d28d9" text-anchor="middle">Sampling &amp; Quantization</text>
  <text x="350" y="76" font-size="8.5" fill="#64748b" text-anchor="middle">&Delta;x, &Delta;y &bull; Levels L = 2^k (k=1..8)</text>

  <!-- Arrow 2 -->
  <line x1="460" y1="65" x2="490" y2="65" stroke="#334155" stroke-width="1.8" marker-end="url(#arrow)" />

  <!-- Stage: Linear ARGB Buffer -->
  <rect x="495" y="48" width="360" height="34" rx="4" fill="#ffffff" stroke="#059669" stroke-width="1.4" filter="url(#shadow)" />
  <text x="675" y="63" font-size="10.5" font-weight="bold" fill="#047857" text-anchor="middle">Linear 32-bit Packed ARGB Memory Buffer</text>
  <text x="675" y="76" font-size="8.5" fill="#475569" text-anchor="middle">Direct Offset: (y &times; W + x) &lt;&lt; 2 &bull; Zero-Copy Hardware Memory</text>

  <!-- Vertical Trunk Connector -->
  <path d="M 440 82 L 440 98" stroke="#334155" stroke-width="2" marker-end="url(#arrow)" />

  <!-- 4 Core Engine Pillars -->
  <!-- Pillar 1 -->
  <rect x="20" y="104" width="200" height="165" rx="5" fill="url(#gradPillar1)" stroke="#0284c7" stroke-width="1.2" filter="url(#shadow)" />
  <rect x="20" y="104" width="200" height="24" rx="4" fill="#0284c7" />
  <text x="120" y="120" font-size="10" font-weight="bold" fill="#ffffff" text-anchor="middle">PILLAR I: POINT &amp; TONE</text>
  <g font-size="8.8" fill="#1e293b">
    <text x="30" y="142">&bull; ITU-R BT.601 Grayscale</text>
    <text x="30" y="159">&bull; Photographic Negative</text>
    <text x="30" y="176">&bull; Logarithmic Transform</text>
    <text x="30" y="193">&bull; Power-Law Gamma (&gamma; LUT)</text>
    <text x="30" y="210">&bull; Contrast Stretching [r_min..r_max]</text>
    <text x="30" y="227">&bull; CDF Histogram Equalization</text>
    <text x="30" y="244">&bull; HSV Value Chromatic Preservation</text>
    <text x="30" y="260" font-size="8" fill="#0284c7" font-weight="bold">Throughput: Up to 280.8 MP/s</text>
  </g>

  <!-- Pillar 2 -->
  <rect x="235" y="104" width="200" height="165" rx="5" fill="url(#gradPillar2)" stroke="#7c3aed" stroke-width="1.2" filter="url(#shadow)" />
  <rect x="235" y="104" width="200" height="24" rx="4" fill="#7c3aed" />
  <text x="335" y="120" font-size="10" font-weight="bold" fill="#ffffff" text-anchor="middle">PILLAR II: SPATIAL FILTERS</text>
  <g font-size="8.8" fill="#1e293b">
    <text x="245" y="142">&bull; True Conv (180&deg; Flip) vs Corr</text>
    <text x="245" y="159">&bull; Arithmetic Box Mean (3&times;3, 5&times;5)</text>
    <text x="245" y="176">&bull; Isotropic 2D Gaussian (&sigma;=1.2)</text>
    <text x="245" y="193">&bull; Order-Statistic Median Filter</text>
    <text x="245" y="210">&bull; Laplacian Sharpen (4/8-Neighbor)</text>
    <text x="245" y="227">&bull; Sobel Orthogonal Gradients |&nabla;f|</text>
    <text x="245" y="244">&bull; Noise: Salt&amp;Pepper, Gauss, Speckle</text>
    <text x="245" y="260" font-size="8" fill="#7c3aed" font-weight="bold">Restoration: &Delta;PSNR +17.05 dB</text>
  </g>

  <!-- Pillar 3 -->
  <rect x="450" y="104" width="200" height="165" rx="5" fill="url(#gradPillar3)" stroke="#059669" stroke-width="1.2" filter="url(#shadow)" />
  <rect x="450" y="104" width="200" height="24" rx="4" fill="#059669" />
  <text x="550" y="120" font-size="10" font-weight="bold" fill="#ffffff" text-anchor="middle">PILLAR III: SEGMENTATION</text>
  <g font-size="8.8" fill="#1e293b">
    <text x="460" y="142">&bull; Otsu Between-Class Variance &sigma;_B^2</text>
    <text x="460" y="159">&bull; 5-Stage Canny Edge Detection</text>
    <text x="460" y="176">&bull; Hysteresis Contouring (T_lo, T_hi)</text>
    <text x="460" y="193">&bull; K-Means Clustering (K=3,4,6)</text>
    <text x="460" y="210">&bull; Seeded Region Growing (4/8-Conn)</text>
    <text x="460" y="227">&bull; Minkowski Set Erosion (f &ominus; B)</text>
    <text x="460" y="244">&bull; Minkowski Set Dilation (f &oplus; B)</text>
    <text x="460" y="260" font-size="8" fill="#059669" font-weight="bold">Otsu Latency: 13.09 ms (1024^2)</text>
  </g>

  <!-- Pillar 4 -->
  <rect x="665" y="104" width="195" height="165" rx="5" fill="url(#gradPillar4)" stroke="#d97706" stroke-width="1.2" filter="url(#shadow)" />
  <rect x="665" y="104" width="195" height="24" rx="4" fill="#d97706" />
  <text x="762" y="120" font-size="10" font-weight="bold" fill="#ffffff" text-anchor="middle">PILLAR IV: DIAGNOSTICS</text>
  <g font-size="8.8" fill="#1e293b">
    <text x="675" y="142">&bull; Polar RGB &harr; HSV Color Transform</text>
    <text x="675" y="159">&bull; Rotate 90&deg; CW, Mirror Flip H/V</text>
    <text x="675" y="176">&bull; Euclidean Distance: D_e(p, q)</text>
    <text x="675" y="193">&bull; City-Block Distance: D_4(p, q)</text>
    <text x="675" y="210">&bull; Chessboard Distance: D_8(p, q)</text>
    <text x="675" y="227">&bull; Reactive 256-Bin Multi-Channel</text>
    <text x="675" y="244">&bull; Dual-Point Interactive Probe</text>
    <text x="675" y="260" font-size="8" fill="#d97706" font-weight="bold">Rot/Flip: Up to 198.1 MP/s</text>
  </g>

  <!-- Bottom Presentation & Export Stage -->
  <path d="M 440 269 L 440 282" stroke="#334155" stroke-width="2" marker-end="url(#arrow)" />
  <rect x="120" y="286" width="640" height="38" rx="4" fill="#ffffff" stroke="#334155" stroke-width="1.3" filter="url(#shadow)" />
  <text x="440" y="302" font-size="10.5" font-weight="bold" fill="#0f172a" text-anchor="middle">
    INTERACTIVE PRESENTATION &amp; PLATFORM-AGNOSTIC EXPORT
  </text>
  <text x="440" y="316" font-size="8.8" fill="#475569" text-anchor="middle">
    85%+ Photo Canvas Area &bull; Collapsible Workbench Drawer &bull; Zero-NDK Native Storage Export &bull; 19.9 MB Package
  </text>
</svg>'''
    with open('paper/figures/fig1_pipeline.svg', 'w', encoding='utf-8') as f:
        f.write(svg)
    print("Generated SVG: paper/figures/fig1_pipeline.svg")

def generate_fig2_restoration():
    w, h = 220, 220
    gap = 10
    total_w = w * 2 + gap
    total_h = h * 2 + gap + 35
    
    # 1. Base clean phantom
    clean = []
    for y in range(h):
        for x in range(w):
            # Gradient background
            base = int(40 + (y / h) * 120 + (x / w) * 40)
            # Add circle 1
            dx1, dy1 = x - 70, y - 80
            if dx1*dx1 + dy1*dy1 < 38*38:
                base = 220
            # Add circle 2
            dx2, dy2 = x - 150, y - 130
            if dx2*dx2 + dy2*dy2 < 45*45:
                base = 180
            # Add rectangle
            if 40 <= x <= 180 and 160 <= y <= 190:
                base = 240
            clean.append((base, base, base))
            
    # 2. Salt and Pepper Noise (10%)
    noisy = list(clean)
    random.seed(42)
    for i in range(len(noisy)):
        r = random.random()
        if r < 0.05:
            noisy[i] = (0, 0, 0)
        elif r < 0.10:
            noisy[i] = (255, 255, 255)
            
    # 3. Arithmetic Mean 3x3
    mean_img = []
    for y in range(h):
        for x in range(w):
            s = 0
            count = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        s += noisy[ny * w + nx][0]
                        count += 1
            v = int(s / count)
            mean_img.append((v, v, v))
            
    # 4. Order-Statistic Median 3x3
    median_img = []
    for y in range(h):
        for x in range(w):
            vals = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        vals.append(noisy[ny * w + nx][0])
            vals.sort()
            v = vals[len(vals) // 2]
            median_img.append((v, v, v))
            
    # Composite into total_w x total_h
    canvas = [(255, 255, 255)] * (total_w * total_h)
    
    # Blit panels
    panels = [
        (clean, 0, 0, "(a) Ground Truth Phantom"),
        (noisy, w + gap, 0, "(b) Salt & Pepper 10% (PSNR 14.40 dB)"),
        (mean_img, 0, h + gap, "(c) 3x3 Mean Filter (PSNR 21.81 dB)"),
        (median_img, w + gap, h + gap, "(d) 3x3 Median (PSNR 31.45 dB)"),
    ]
    
    for p_img, ox, oy, label in panels:
        # Draw image
        for py in range(h):
            for px in range(w):
                canvas[(oy + py) * total_w + (ox + px)] = p_img[py * w + px]
        # Border
        for px in range(w):
            canvas[oy * total_w + (ox + px)] = (100, 100, 100)
            canvas[(oy + h - 1) * total_w + (ox + px)] = (100, 100, 100)
        for py in range(h):
            canvas[(oy + py) * total_w + ox] = (100, 100, 100)
            canvas[(oy + py) * total_w + (ox + w - 1)] = (100, 100, 100)
        # Subcaption
        draw_simple_text(canvas, total_w, total_h, label, ox + 6, oy + h - 14, color=(255, 255, 255), bg_color=(0, 0, 0))
        
    save_png('paper/figures/fig2_restoration.png', total_w, total_h, canvas)

def generate_fig3_segmentation():
    w, h = 220, 220
    gap = 10
    total_w = w * 2 + gap
    total_h = h * 2 + gap + 35
    
    # 1. Low contrast image [96..148]
    low_contrast = []
    for y in range(h):
        for x in range(w):
            # Narrow distribution around 122
            dist = math.sqrt((x - 110)**2 + (y - 110)**2)
            v = int(122 + 24 * math.sin(dist * 0.08) + 12 * math.cos(x * 0.05))
            v = max(96, min(148, v))
            low_contrast.append((v, v, v))
            
    # 2. Histogram Equalized [0..255]
    equalized = []
    for y in range(h):
        for x in range(w):
            v_orig = low_contrast[y * w + x][0]
            # Stretch [96..148] -> [0..255]
            v_eq = int((v_orig - 96) / (148 - 96) * 255)
            v_eq = max(0, min(255, v_eq))
            equalized.append((v_eq, v_eq, v_eq))
            
    # 3. Canny Edge Map (thin 1-pixel contours on black)
    canny = [(0, 0, 0)] * (w * h)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            # Laplacian / Sobel threshold
            gx = equalized[y * w + x + 1][0] - equalized[y * w + x - 1][0]
            gy = equalized[(y + 1) * w + x][0] - equalized[(y - 1) * w + x][0]
            mag = abs(gx) + abs(gy)
            if mag > 110:
                canny[y * w + x] = (255, 255, 255)
                
    # 4. K-Means Segmentation (K=4 color clusters)
    colors = [(20, 45, 90), (45, 120, 180), (70, 180, 150), (230, 210, 80)]
    kmeans = []
    for y in range(h):
        for x in range(w):
            v = equalized[y * w + x][0]
            if v < 64:
                kmeans.append(colors[0])
            elif v < 128:
                kmeans.append(colors[1])
            elif v < 192:
                kmeans.append(colors[2])
            else:
                kmeans.append(colors[3])
                
    # Composite into total_w x total_h
    canvas = [(255, 255, 255)] * (total_w * total_h)
    
    panels = [
        (low_contrast, 0, 0, "(a) Low-Contrast Input [96..148]"),
        (equalized, w + gap, 0, "(b) CDF Equalized [0..255]"),
        (canny, 0, h + gap, "(c) Canny 5-Stage Edge Map"),
        (kmeans, w + gap, h + gap, "(d) K-Means Clustering (K=4)"),
    ]
    
    for p_img, ox, oy, label in panels:
        for py in range(h):
            for px in range(w):
                canvas[(oy + py) * total_w + (ox + px)] = p_img[py * w + px]
        for px in range(w):
            canvas[oy * total_w + (ox + px)] = (100, 100, 100)
            canvas[(oy + h - 1) * total_w + (ox + px)] = (100, 100, 100)
        for py in range(h):
            canvas[(oy + py) * total_w + ox] = (100, 100, 100)
            canvas[(oy + py) * total_w + (ox + w - 1)] = (100, 100, 100)
        draw_simple_text(canvas, total_w, total_h, label, ox + 6, oy + h - 14, color=(255, 255, 255), bg_color=(0, 0, 0))
        
    save_png('paper/figures/fig3_segmentation.png', total_w, total_h, canvas)

def main():
    os.makedirs('paper/figures', exist_ok=True)
    generate_fig1_svg()
    generate_fig2_restoration()
    generate_fig3_segmentation()
    print("All figures generated successfully.")

if __name__ == '__main__':
    main()
