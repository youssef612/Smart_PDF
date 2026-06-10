# SHpm97gRN4O3fvQ1bKrFICUtsCm2hKGk01IFD0ZT — Extracted Content

*Characters: 14,475 | marker-pdf server*

---

![](_page_0_Picture_0.jpeg)

# **video steganography**

- ❑ Video steganography is a method of hiding secret data within a video file in a way that doesn't make the hidden data noticeable.
- ❑ It uses video frames to conceal data so that the carrier (the video file) appears unaltered to the human eye, but hidden data can be extracted using specialized software.

# Video

- ❑ A video is a sequence of images called frames.
- ❑ Each frame is a two-dimensional grid of pixels.
- ❑ A set of connected pixels is called a "blob

![](_page_3_Figure_0.jpeg)

# Video

- ❑ a sequence of still images representing scenes in motion.
- ❑ **Note: Animation starts from discrete pictures**  and then process to illusion of continuous motion.

![](_page_5_Picture_1.jpeg)

![](_page_5_Picture_2.jpeg)

![](_page_5_Picture_3.jpeg)

![](_page_5_Picture_4.jpeg)

#### **Basics of Video Representation (frame)**

- ❑ **A video is a sequence of individual still images called frames.**
- ❑ **When played in quick succession, these frames create the perception of motion.**

![](_page_6_Picture_3.jpeg)

![](_page_6_Picture_4.jpeg)

#### I-frames

- ➢ I-frames, also known as intra-coded frames, are coded independently without reference to any other frames
- ➢ **I-frame** is a self-containing frame that does not need references to other frames.

![](_page_7_Picture_3.jpeg)

#### **P-Frame**

➢ P-frames (predictive-coded frames) obtain predictions from temporally preceding I- or P-frames in the sequence, which is known as forward prediction.

![](_page_8_Picture_2.jpeg)

# B-Frame

frames in a video clip that are produced by the encoder using both forward and backward reference to previous/next I or Pframes

![](_page_9_Picture_2.jpeg)

#### **Example**

- ❑ The frame that contains the full information from the image even when compressed is called the keyframe, also known as the I frame.
- ❑ P/ B frames record only the differences in other words, the running person.

![](_page_10_Figure_3.jpeg)

![](_page_10_Figure_4.jpeg)

## **Basics of Video Representation**

- ❑ **Frame rate**, which indicates the number of frames per time unit of the video
- ➢ frames per second (fps)
- ❑ **Bit rate**, which measures the rate of the information content in a video stream.
- ➢ bit per second (bit/s or bps) or Megabit per second (Mbit/s or Mbps).

#### **Resolution and Aspect Ratio**

- ❑ Resolution refers to the number of pixels displayed on a screen.
- ❑ a high-resolution screen will display more detail in an image or video than a lower-resolution screen.
- ❑ Common resolutions include:
- ➢ SD (Standard Definition) 720x480 or 640x480
- ➢ HD (High Definition) 1280x720

![](_page_13_Figure_0.jpeg)

## **Resolution and Aspect Ratio**

- ❑ Aspect Ratio refers to the proportional relationship
- between a video's width and height.
- ❑ It's expressed as two numbers separated
- ❑ Common aspect ratios are **16:9** (widescreen, common
- for HD and UHD) and **4:3** (standard definition).

![](_page_15_Figure_0.jpeg)

## **Color Representation**

- ❑ Color space is a mathematical representation of a range of colors.
- ❑ When referring to video, many people use the term "color space" when referring to the "color model."
- ❑ Some common color models include RGB, YUV 4:4:4, YUV 4:2:2, and YUV 4:2:0.

![](_page_17_Picture_0.jpeg)

#### **RGB (Red, Green, Blue**)

- ❑ In the RGB color model, each color is created by combining red, green, and blue channels in varying intensities.
- ❑ **Pros:**
- ❖ Excellent for quality and accurate color reproduction, especially in applications where fidelity is key (e.g., design and imaging).
- ❑ **Cons:**
- ❖ High storage requirements since all channels have full color data; not efficient for video compression.

#### **Color Representation**

- ❑ YUV color model where Y stands for the luma component (the brightness) and U and V are the chrominance (color) components
- ❑ **Application**: Widely used in video compression and broadcasting, especially where the efficiency of storage or transmission is essential.

![](_page_18_Figure_3.jpeg)

#### YUV 4:4:4, YUV 4:2:2, and YUV 4:2:0

- ❖ Full color depth is usually referred to as 4:4:4.
- ❖ The first number indicates that there are four pixels across,
- ❖ the second indicates that there are four unique colors,
- ❖ the third indicates that there are four changes in color for the second row

## **Variants of YUV (4:4:4)**

- •**Description**: In this model, all three channels (Y', Cb, and Cr) have the same resolution, meaning there is no chroma subsampling.
- •**Pros**: Excellent quality, as no color data is lost.
- •**Cons:** Requires a large amount of data storage and bandwidth.

![](_page_20_Figure_4.jpeg)

**)**

## **Variants of YUV (4:2:2)**

- ❑ the chrominance channels (Cb and Cr) are halved in the horizontal resolution compared to the luminance channel.
- ❑ For every four Y' samples, there are two Cb and two Cr samples.

![](_page_21_Picture_3.jpeg)

#### **Variants of YUV (4:2:0)**

- ❑ chrominance is subsampled by half in both horizontal and vertical resolutions.
- ❑ For every four Y' samples, there is one Cb and one Cr sample.

| Y     | Y | Y     | Y |
|-------|---|-------|---|
| Cb Cr |   | Cb Cr |   |
| Y     | Y | Y     | Y |
|       |   |       |   |

#### **Why Chroma Subsampling?**

- ❑ Chroma subsampling involves the reduction of color resolution in video signals to save bandwidth.
- ❑ Reduces the color information in a video without significantly affecting perceived quality
- ❑ Although color information is discarded, human eyes are much more sensitive to variations in brightness than in color.

# **Ycbcr Color Model**

Y represents brightness (luminance), and Cb and Cr represent color information (chrominance).

![](_page_24_Picture_2.jpeg)

#### **Basics of Video Representation**

![](_page_25_Picture_1.jpeg)

# **Interlacing**

- ❑ The scan lines of each interlaced frame are numbered consecutively and partitioned into two fields: : it starts with the odd lines (1, 3, 5, ...) and then continues with the even lines (2, 4, 6,...).
- ❑ If the first field starts with an odd line it is called "upper field first", if it starts with an even line, it is called "lower field first".

![](_page_27_Figure_1.jpeg)

#### **Progressive Scan**

- ➢ With progressive scan systems, each refresh period updates all of the scan lines.
- ➢ This results in a higher perceived resolution and a lack of various artifacts that can make parts of a stationary picture appear to be moving or flashing

![](_page_29_Figure_0.jpeg)

### **Audio-Video Synchronization**

- ❑ Audio-video synchronization, often called A/V sync, is the process of aligning audio and video tracks in a way that makes them play back in perfect timing with each other.
- ❑ This synchronization ensures that sounds match the corresponding visual events (e.g., dialogue, actions), providing a cohesive viewing experience.

### **Audio-Video Synchronization**

- ❑ Multiplexing (or muxing) is the process of combining audio and video streams into a single container file with synchronized timestamps.
- ❑ **Timestamps** are used to indicate when each audio and video frame should be played. These timestamps ensure the correct alignment of audio samples with video frames.

#### Metadata

- ❖ Metadata contains information about the video file, such as title, author, codec, frame rate, and resolution.
- ❖ It's essential for organizing, searching, and playing back video files

## Types of Video signal

- ❑ Video signals represent moving images in different formats and standards, and these can vary based on the type of technology, resolution, and transmission medium
- ❑ Two types of Video Signal
- ❑ Analog video
- ❑ Digital video

## **Analog Video Signal**

❑ Analog video represents video information in continuous waves and is commonly found in older technologies.

![](_page_34_Picture_2.jpeg)

# Digital Video Signal

❑ Digital video converts video data into binary format (0s and 1s), enabling higher resolutions, data compression, and compatibility with computers and modern displays.

![](_page_35_Picture_2.jpeg)

![](_page_35_Picture_3.jpeg)

**DVI**

![](_page_35_Picture_4.jpeg)

![](_page_35_Picture_5.jpeg)

**HDMI**

## **Ways to reduce video file size**

Reduce the size of the playback window - Internet - 160 x 120 pixels. Decrease the number of colors, from 16 million to 256 or even 16 colors. Reduce the frame rate from 30 down to 15 or less frames per second but more jerky.

Compress the file.

#### types of Video Compressions

- ❑ Video compression reduces the file size of video content, making it more efficient for storage and transmission.
- ❑ There are two primary categories of video compression
- lossy and lossless

#### Lossless Video Compression

- ❑ Lossless compression retains all the original data, allowing for exact reproduction of the original video.
- ❑ While it doesn't reduce file size as much as lossy compression, it is valuable when quality must be preserved, such as in professional video production and archiving.

#### Lossy Video Compression

- ❑ Lossy compression discards some data, achieving significant reductions in file size by compressing less noticeable information.
- ❑ While it reduces video quality to some extent, modern lossy codecs are designed to minimize visible quality loss.

#### **Intra-frame Compression (Spatial Compression)**

- ➢ Specifically, intra-frame compression is applied to code I-frames
- ➢ Each frame is compressed independently.
- ➢ The single image frame is divided into blocks and differences are noted between each pixel and these are encoded

## **Inter-Frame Compression (Temporal Compression)**

- ❑ Inter-frame compression is a type of compression that is based on what happens across frames
- ❑ Reduces redundancy across multiple frames by only storing changes between frames.

#### How Video Steganography Works?

#### **1. Frame Selection and Manipulation:**

- ❖ The video is composed of multiple frames (essentially still images).
- ❖ Data can be embedded in each frame, or in selected frames, to avoid suspicion.

### How Video Steganography Works?

#### **2. Encoding Techniques**

- ❖ Spatial Domain Techniques
- ❖ Transform Domain Techniques
- ❖ Spread Spectrum Techniques

#### Frame Selection in Video Steganography

- ❑ Frame selection is the process of choosing specific frames within a video sequence to hide information.
- ❑ Rather than embedding data in every frame (which might be too **noticeable or redundant**), frame selection ensures that data is placed in carefully chosen frames where it's less likely to be detected and where changes are less perceptible.

#### **Techniques in Frame Selection**

#### **1. Key Frames Selection:**

- ❑ Keyframes, or I-frames (intra-coded frames), are frames that contain complete image data and do not rely on other frames.
- ❑ Since keyframes are more static
- ❑ However, using only keyframes limits the amount of data that can be embedded due to the lower frequency of keyframes.

#### **Techniques in Frame Selection**

#### ❖ **2. Non-Key Frame Selection:**

- ❖ Non-key frames like P-frames (predicted frames) and B-frames (bidirectional frames) rely on motion prediction and reference other frames.
- ❖ This approach can be more challenging but can support higher data capacity

#### **Techniques in Frame Selection**

- ❖ **Random Frame Selection:**
- ❖ **Randomly selected frames across the video sequence are used for embedding data.**
- ❖ **This helps reduce detection, as a random distribution makes it harder for unauthorized viewers to locate the hidden data.**
- ❖ **Random frame selection is effective for hiding small amounts of data across a large video.**

#### **Block-Based Embedding in Video Steganography**

- ❑ Once frames are selected, block-based embedding is used to decide which areas of each frame should contain the hidden data.
- ❑ A video frame is typically divided into smaller blocks or macroblocks (e.g., 8x8 or 16x16 pixels), making it easier to manage data hiding and adjust embedding based on block characteristics.

#### **Techniques in Block-Based Embedding**

#### 1. **Fixed Block Size:**

Blocks of a fixed size (such as 8x8 pixels) are selected within each frame, and data is embedded in each block.

#### **2. Variable Block Size**:

•Block sizes can be varied based on the amount of data to embed or based on the complexity of the region in the frame

#### **3. Transform-Based Blocks:**

•Transform-based algorithms, like **DCT** (Discrete Cosine Transform) and **DWT** (Discrete Wavelet Transform), divide frames into transform blocks, embedding data in the frequency components rather than the spatial pixel values.

![](_page_50_Figure_0.jpeg)

# **Steganalysis**

- ❑ Steganalysis is the process of detecting, analyzing, and possibly extracting hidden information within a digital medium like images, audio, or video.
- ❑ If decrypting the payload was impossible, **destroying** it is also considered a part of steganalys is work.

### **Types of Steganalysis**

There are two primary types of steganalysis techniques:

- ❑ specific
- ❑ universal.

![](_page_52_Figure_4.jpeg)

## **Types of Steganalysis**

- ❑ **Specific Steganalysis**:
- ❑ Tailored to detect hidden data embedded using a particular steganography algorithm.
- ❑ Often more accurate but limited to detecting data from known methods, such as Least Significant Bit (LSB) or Discrete Cosine Transform (DCT) based steganography

#### **Types of Steganalysis**

- **2. Universal Steganalysis:**
- ❑ **Universal steganalysis techniques are designed to detect hidden data without prior knowledge of the embedding algorithm.**
- ❑ **Types**
- **1. Binary similarity measure**
- **2. Wavelet-based**
- **3. Markov process-based**

## **Steganalysis methods**

![](_page_55_Figure_1.jpeg)

#### **Stego-Only Attack**

In a stego-only attack, the analyst has only the stego video or image and no access to the original, unaltered file (cover).

In this attack, the stagnoanalysis needs to try every possible steganography algorithms and related attacks to recover the hidden information.

#### **Steganalysis methods**

#### **Known-Cover Attack**

Both the stego object and the original cover file is available.

#### **Known Stego Attack**

- ❑ both the **steganography algorithm** used to conceal the secret message/file is known
- ❑ and we already have the
- ➢ **stego** object
- ➢ an **original** file