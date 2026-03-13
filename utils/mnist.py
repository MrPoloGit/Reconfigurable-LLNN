import torch
from torchvision.datasets import MNIST, FashionMNIST
from torchvision.transforms import transforms


class MNIST20Transform:
    def __call__(self, image: torch.Tensor) -> torch.Tensor:
        top, bottom = self.get_offsets(image, "row")
        image = image[:, top:28 - bottom]
        
        left, right = self.get_offsets(image, "column")
        image = image[:, :, left:28 - right]
        return image

    def get_offsets(self, image, direction):
        if "row" in direction:
            dim = 2
        elif "column" in direction:
            dim = 1
        lines = ~image.any(dim=dim)
        _, counts = torch.unique_consecutive(lines, return_counts=True)
        value1 = counts[0]
        value2 = counts[-1]
        if value1 + value2 > 9:
            both_sides = min(value1, value2)
            if both_sides > 4:
                both_sides = 4
            value2 = both_sides
            first = 8 - (both_sides * 2)
            value1 = (first + both_sides)
        if value1 + value2 == 9:
            if value1 == 0:
                value2 -= 1
            else:
                value1 -= 1
        assert value1 + value2 == 8, (value1, value2)
        return value1, value2


def load_mnist_dataset(batch_size, mnist20=False, rotate_90=False, fashion=False):
    trans = [transforms.ToTensor()]
    
    if rotate_90:
        # Rotate 90 degrees left (k=1) on the H, W dimensions
        trans.append(transforms.Lambda(lambda x: torch.rot90(x, k=1, dims=[1, 2])))
        
    if mnist20:
        if fashion:
            trans.append(transforms.CenterCrop(20))
        else:
            trans.append(MNIST20Transform())
    transform = transforms.Compose(trans)
    DatasetClass = FashionMNIST if fashion else MNIST
    train_set = DatasetClass('./data-mnist', train=True, download=True, transform=transform)
    test_set = DatasetClass('./data-mnist', train=False, transform=transform)

    # train_loader = torch.utils.data.DataLoader(train_set, batch_size=batch_size, shuffle=True, pin_memory=True,
    #                                            drop_last=True, num_workers=4)
    # test_loader = torch.utils.data.DataLoader(test_set, batch_size=batch_size, shuffle=False, pin_memory=True,
    #                                           drop_last=True)
    train_loader = torch.utils.data.DataLoader(train_set, batch_size=batch_size, shuffle=True, pin_memory=False,
                                               drop_last=True, num_workers=0)
    test_loader = torch.utils.data.DataLoader(test_set, batch_size=batch_size, shuffle=False, pin_memory=False,
                                              drop_last=True)

    input_dim_dataset = 400
    num_classes = 10
    return train_loader, test_loader, input_dim_dataset, num_classes
