#!/usr/bin/env python3
"""Swap two variables without using a third variable."""


def swap_tuple(a: int, b: int) -> tuple[int, int]:
    """Pythonic tuple unpacking."""
    return b, a


def swap_arithmetic(a: int, b: int) -> tuple[int, int]:
    """Arithmetic approach (works for numbers only)."""
    a = a + b
    b = a - b
    a = a - b
    return a, b


def swap_xor(a: int, b: int) -> tuple[int, int]:
    """XOR approach (works for integers only)."""
    a = a ^ b
    b = a ^ b
    a = a ^ b
    return a, b


if __name__ == "__main__":
    x, y = 10, 25
    
    print(f"Before: x={x}, y={y}")
    
    # Tuple unpacking (recommended)
    x, y = swap_tuple(x, y)
    print(f"After swap_tuple: x={x}, y={y}")
    
    # Verify arithmetic works too
    x, y = 10, 25
    x, y = swap_arithmetic(x, y)
    print(f"After swap_arithmetic: x={x}, y={y}")
    
    # Verify XOR works too
    x, y = 10, 25
    x, y = swap_xor(x, y)
    print(f"After swap_xor: x={x}, y={y}")
