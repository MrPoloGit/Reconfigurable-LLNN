import argparse
import numpy as np
import random, os
import torch
from torch.optim.lr_scheduler import ReduceLROnPlateau, ExponentialLR
from tqdm import tqdm
from lutnn.lutnn import LUTNN
from utils.mnist import load_mnist_dataset
from utils.cifar10 import load_cifar10_dataset
from utils.uci_datasets import AdultDataset, BreastCancerDataset
from utils.jsc import JetSubstructureDataset

# Hardware Descriptor Languages
from hdl.convert2vhdl import get_model_params, gen_vhdl_code
from hdl.convert2sv import gen_sv_code

# Cleaning
import shutil
import sys
from pathlib import Path

def get_args():
    parser = argparse.ArgumentParser(description='Train LUTNN.')

    # clean
    parser.add_argument("--clean", choices=["models", "data", "all"], help="Delete generated artifacts. Use with --name to delete only that model's outputs.")
    
    parser.add_argument('--dataset', type=str, choices=['mnist', 'mnist20x20', 'cifar10-3', 'cifar10-31', 'adult', 'breast', 'jsc'], default="mnist20x20", help='Dataset to use')
    parser.add_argument('--seed', type=int, default=0, help='seed (default: 0)')
    parser.add_argument('--batch-size', '-bs', type=int, default=128, help='batch size (default: 128)')
    parser.add_argument('--learning-rate', '-lr', type=float, default=0.01, help='learning rate (default: 0.01)')
    parser.add_argument('--tau', '-t', type=float, default=10, help='the softmax temperature of the aggregation output')

    parser.add_argument('--num-iterations', '-ni', type=int, default=15_000, help='Number of training iterations (default: 15000)')
    parser.add_argument('--eval-freq', '-ef', type=int, default=1_000, help='Evaluation frequency (default: 1000)')
    parser.add_argument('--connections', type=str, default='unique', choices=['random', 'unique'])
    parser.add_argument('--luts_per_layer', '-k', nargs='*', type=int, default=[2000], help='LUTs per layer (default: 2000)')
    parser.add_argument('--num_layers', '-l', type=int, default=2, help='Number of layers (default: 2)')
    parser.add_argument('--lut_size', '-s', nargs='*', type=int, default=[2], help='LUT input size (default: 2)')

    parser.add_argument('--name', type=str, help='Experiment name')
    parser.add_argument('--vhdl', action='store_true', help='Get VHDL code from net weights.')

    # system verilog
    parser.add_argument('--sv', action='store_true', help='Get system verilog code from net weights.')

    parser.add_argument('--save', action='store_true', help='Save model weights.')
    parser.add_argument('--train', action='store_true', help='Train model.')
    parser.add_argument('--load', action='store_true', help='Load model')
    parser.add_argument('--infer_time', action='store_true', help='Measure inference time')
    return parser.parse_args()


def set_seeds(seed):
    torch.manual_seed(seed)
    random.seed(seed)
    np.random.seed(seed)


def train(model, train_loader, test_loader, args, device):
    scaler = torch.cuda.amp.GradScaler()
    loss_fn = torch.nn.CrossEntropyLoss(label_smoothing=0)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.learning_rate)
    scheduler = ReduceLROnPlateau(optimizer, 'max', factor=0.8, cooldown=5, min_lr=0.0001)
    iterator = iter(train_loader)
    for i in tqdm(range(args.num_iterations), desc='Training', total=args.num_iterations):
        try:
            x, y = next(iterator)
        except StopIteration:
            iterator = iter(train_loader)
            x, y = next(iterator)
        x = x.to(torch.float32).to(device).round()
        y = y.to(device)

        optimizer.zero_grad()
        y_pred = model(x)

        class_loss = loss_fn(y_pred, y)

        scaler.scale(class_loss).backward()
        scaler.step(optimizer)
        scaler.update()

        if (i + 1) % args.eval_freq == 0:
            train_accuracy_eval_mode = evaluation(model, train_loader, device, mode=False)
            test_accuracy_eval_mode = evaluation(model, test_loader, device, mode=False)
            test_accuracy_train_mode = evaluation(model, test_loader, device, mode=True)

            scheduler.step(test_accuracy_eval_mode)
            print(f' LR: {scheduler._last_lr},'
                  f' train_acc_eval_mode: {train_accuracy_eval_mode},'
                  f' test_acc_eval_mode: {test_accuracy_eval_mode},'
                  f' test_acc_train_mode: {test_accuracy_train_mode},'
                  f' class_loss: {class_loss}')

    return model


def evaluation(model, loader, device, mode=False):
    with torch.no_grad():
        model.train(mode=mode)
        result = []
        for x, y in loader:
            x = x.to(device)
            y = y.to(device)
            result.append(((model(x).argmax(-1) == y).sum() / x.shape[0]).item())
        result = np.mean(result)
    model.train()
    return result.item()


def load_dataset(args):
    if "mnist20x20" in args.dataset:
        train_loader, test_loader, input_dim_dataset, num_classes = load_mnist_dataset(args.batch_size, mnist20=True)
    elif "mnist" in args.dataset:
        train_loader, test_loader, input_dim_dataset, num_classes = load_mnist_dataset(args.batch_size, mnist20=False)
    elif "adult" in args.dataset:
        train_set = AdultDataset('./data-uci', split='train', download=True, with_val=False)
        test_set = AdultDataset('./data-uci', split='test', with_val=False)
        train_loader = torch.utils.data.DataLoader(train_set, batch_size=args.batch_size, shuffle=True)
        test_loader = torch.utils.data.DataLoader(test_set, batch_size=int(1e6), shuffle=False)
        input_dim_dataset = 116
        num_classes = 2
    elif "breast" in args.dataset:
        train_set = BreastCancerDataset('./data-uci', split='train', download=True, with_val=False)
        test_set = BreastCancerDataset('./data-uci', split='test', with_val=False)
        train_loader = torch.utils.data.DataLoader(train_set, batch_size=args.batch_size, shuffle=True)
        test_loader = torch.utils.data.DataLoader(test_set, batch_size=int(1e6), shuffle=False)
        input_dim_dataset = 51
        num_classes = 2
    elif "cifar10-3" in args.dataset:
        train_loader, test_loader, input_dim_dataset, num_classes = load_cifar10_dataset(args.batch_size, 3)
    elif "cifar10-31" in args.dataset:
        train_loader, test_loader, input_dim_dataset, num_classes = load_cifar10_dataset(args.batch_size, 31)
    elif "jsc" in args.dataset:
        thresholds = 30
        train_set = JetSubstructureDataset("./data-jsc", thresholds=thresholds, split="train", download=True)
        test_set = JetSubstructureDataset("./data-jsc", thresholds=thresholds, split="test", download=True)
        train_loader = torch.utils.data.DataLoader(train_set, batch_size=args.batch_size, shuffle=True)
        test_loader = torch.utils.data.DataLoader(test_set, batch_size=args.batch_size, shuffle=False)
        input_dim_dataset = 16*(thresholds-1)
        num_classes = 5
    return train_loader, test_loader, input_dim_dataset, num_classes

# Clean ------------------------------------------------------------------------------------------------
from pathlib import Path
import shutil

def _rm_path(p: Path):
    if not p.exists():
        return
    if p.is_dir():
        shutil.rmtree(p)
    else:
        p.unlink()

def clean_artifacts(clean_what: str, name: str | None):
    models_dir = Path("models")
    data_dir = Path("data")

    targets: list[Path] = []

    # models
    if clean_what in ("models", "all"):
        if name:
            # delete just models/<name>.pth
            targets.append(models_dir / f"{name}.pth")
        else:
            # delete all model weights
            targets.append(models_dir)

    # data
    if clean_what in ("data", "all"):
        if name:
            # delete only outputs for that experiment name (covers common layouts)
            targets.extend([
                data_dir / "VHDL" / name,
                data_dir / "vhdl" / name,
                data_dir / "SV" / name,
                data_dir / "sv" / name,
            ])
        else:
            # delete entire data folder
            targets.append(data_dir)

    # Filter non-existent, dedupe
    uniq: list[Path] = []
    seen: set[str] = set()
    for t in targets:
        if t.exists() and str(t) not in seen:
            uniq.append(t)
            seen.add(str(t))
    targets = uniq

    if not targets:
        print("[clean] Nothing to delete.")
        return

    print("[clean] Will delete:")
    for t in targets:
        print(f"  - {t}")

    resp = input("Proceed? [y/N] ").strip().lower()
    if resp not in ("y", "yes"):
        print("[clean] Aborted.")
        return

    for t in targets:
        _rm_path(t)

    print("[clean] Done.")
# --------------------------------------------------------------------------------------------------------

if __name__ == "__main__":
    args = get_args()

    # clean
    if args.clean:
        clean_artifacts(args.clean, args.name)
        sys.exit(0)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    set_seeds(args.seed)

    train_loader, test_loader, input_dim_dataset, num_classes = load_dataset(args)

    if args.load:
        # model = torch.load(f"models/{args.name}.pth")
        model = torch.load(
            f"models/{args.name}.pth",
            weights_only=False
        )
    else:
        model = LUTNN(args.luts_per_layer, args.num_layers, args.lut_size, input_dim_dataset, num_classes, device, tau=args.tau)
    if args.train:
        model = train(model, train_loader, test_loader, args, device)
    else:
        print(f"Inference accuracy: {evaluation(model, test_loader, device, False)}")
        if args.vhdl:
            number_of_layers, num_neurons, lut_size, number_of_inputs, number_of_classes = get_model_params(model)
            gen_vhdl_code(model, args.name, number_of_layers, number_of_classes, number_of_inputs, num_neurons,
                          lut_size)
        if args.sv:
            number_of_layers, num_neurons, lut_size, number_of_inputs, number_of_classes = get_model_params(model)
            gen_sv_code(model, args.name, number_of_layers, number_of_classes, number_of_inputs, num_neurons,
                          lut_size)
    if args.save:
        directory = "models"
        if not os.path.exists(directory):
            os.makedirs(directory)
        torch.save(model, f"models/{args.name}.pth")
