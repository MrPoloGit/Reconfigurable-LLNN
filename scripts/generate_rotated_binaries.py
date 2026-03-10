import torch
from utils.mnist import load_mnist_dataset

# Load Rotated MNIST20x20
_, test_loader, _, _ = load_mnist_dataset(batch_size=1, mnist20=True, rotate_90=True)

binarized_file_path = "pynq_notebooks/binarized_20x20_MNIST_rotated.txt"
labels_file_path = "pynq_notebooks/mnist_rotated_test_labels.txt"

with open(binarized_file_path, "w") as f_bin, open(labels_file_path, "w") as f_lbl:
    for images, labels in test_loader:
        # Binarize using > 0 threshold (same as LLNN logic)
        images_bin = (images > 0).int()
        
        # Flatten the 20x20 image to 400 bits 
        flat_bin = images_bin.view(-1).tolist()
        
        # Convert the integer array to a contiguous string of '0' and '1'
        bitstring = "".join(str(b) for b in flat_bin)
        
        # Write to files
        f_bin.write(bitstring + "\n")
        f_lbl.write(str(labels.item()) + "\n")

print(f"Successfully generated {binarized_file_path} and {labels_file_path}")
