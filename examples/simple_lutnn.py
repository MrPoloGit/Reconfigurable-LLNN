import argparse
import sys
from pathlib import Path
import torch
import torch.optim as optim

def main():
    parser = argparse.ArgumentParser(description="Train a simple LUTNN")
    parser.add_argument("--epochs", type=int, default=4, help="Number of training epochs")
    parser.add_argument("--batch-size", type=int, default=128, help="Batch size for training")
    parser.add_argument("--lr", type=float, default=0.01, help="Learning rate")
    args = parser.parse_args()

    PROJECT_ROOT = Path(__file__).resolve().parent.parent
    if str(PROJECT_ROOT) not in sys.path:
        sys.path.insert(0, str(PROJECT_ROOT))

    from lutnn.lutlayer import LUTLayer, Aggregation
    from utils.mnist import load_mnist_dataset
    from hdl.convert2vhdl import get_model_params, gen_vhdl_code
    from hdl.convert2sv import gen_sv_code

    train_loader, test_loader, input_dim_dataset, num_classes = load_mnist_dataset(batch_size=args.batch_size, mnist20=True)

    class SimpleLUTNN(torch.nn.Module):
        def __init__(self):
            super(SimpleLUTNN, self).__init__()
            self.layer1 = LUTLayer(input_dim=input_dim_dataset, lut_size=6, n_luts=2048)
            self.layer2 = LUTLayer(input_dim=2048, lut_size=6, n_luts=4000)
            self.layer3 = Aggregation(num_classes=num_classes, tau=10.)

        def forward(self, x):
            x = x.view(-1, 20*20)  # Flatten the input
            x = self.layer1(x)
            x = self.layer2(x)
            x = self.layer3(x)
            return x

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(device)
    model = SimpleLUTNN().to(device)
    criterion = torch.nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=args.lr)

    for epoch in range(args.epochs):
        model.train()
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)
            
            outputs = model(data)
            loss = criterion(outputs, target)
            
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            if batch_idx % 100 == 0:
                print(f'Epoch [{epoch+1}/{args.epochs}], Step [{batch_idx}/{len(train_loader)}], Loss: {loss.item():.4f}')

    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            outputs = model(data)
            _, predicted = torch.max(outputs.data, 1)
            total += target.size(0)
            correct += (predicted == target).sum().item()

    print(f'Test Accuracy: {100 * correct / total:.2f}%')

    model.model = torch.nn.Sequential(
        torch.nn.Flatten(),
        model.layer1,
        model.layer2,
        model.layer3
    )

    number_of_layers, num_neurons, lut_sizes, number_of_inputs, number_of_classes = get_model_params(model)
    model_name = 'simple_lutnn'

    gen_vhdl_code(model, model_name, number_of_layers, number_of_classes, number_of_inputs, num_neurons, lut_sizes)
    print(f'VHDL code generated in data/VHDL/{model_name}/')

    gen_sv_code(model, model_name, number_of_layers, number_of_classes, number_of_inputs, num_neurons, lut_sizes)
    print(f'SystemVerilog code generated in data/sv/{model_name}/')

if __name__ == "__main__":
    main()
