# Canny edge detector

Scilab implementation of the Canny edge detector during a school project.

The Canny edge detector is an edge detection operator that uses a multi-stage algorithm to detect a wide range of edges in images. It was developed by John F. Canny in 1986.

Among the edge detection methods developed so far, canny edge detection algorithm is one of the most strictly defined methods that provides good and reliable detection. Owing to its optimality to meet with the three criteria for edge detection and the simplicity of process for implementation, it becomes one of the most popular algorithms for edge detection.

## Steps

The Process of Canny edge detection algorithm can be broken down to 5 different steps:

1. Apply Gaussian filter to smooth the image in order to remove the noise
2. Compute the intensity gradients of the image
3. Apply non-maximum suppression to get rid of spurious response to edge detection
3. Apply double threshold to determine potential edges
4. Track edge by hysteresis: Finalize the detection of edges by suppressing all the other edges that are weak and not connected to strong edges

Note that the hysteresis threshold can be changed: for a good value, pick something between 70% and 85%.

## Warning

- Possible issues if you use Scilab 64 bits (Scilab 32 bits preferred)
- All the code, comments and the project report (PDF file provided in this repository) are writen in french

## How to use this code?

- Run script in your Scilab env
    + Take a look at the `main` function and do not hesitate to play with some parameters (original image, Gaussian mask and thresholds)
    
## Example

![input](input.png)
![output](output.png)

- Want to know more? 
    + For french speakers: take a look at the project report
    + Wikipedia page: https://en.wikipedia.org/wiki/Canny_edge_detector

