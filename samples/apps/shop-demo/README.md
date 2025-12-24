# Shop Demo

E-commerce application demonstrating product browsing, cart management, and checkout.

## Overview

Shop Demo showcases e-commerce application patterns:
- Product catalog with categories
- Shopping cart management
- Wishlist functionality
- Checkout flow
- Order history

## Project Structure

```
shop-demo/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
```

## Features

### Product Catalog
- Browse by category
- Product search
- Product details
- Image gallery
- Reviews and ratings

### Shopping Cart
- Add/remove items
- Quantity adjustment
- Price calculation
- Discount codes

### Wishlist
- Save for later
- Move to cart
- Share wishlist

### Checkout
- Shipping address
- Payment method
- Order summary
- Confirmation

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Initialization
void app_init(void);
void app_deinit(void);

// Navigation
void app_set_screen(uint8_t screen);
void app_select_category(uint32_t id);
void app_select_product(uint32_t id);

// Cart operations
void app_add_to_cart(uint32_t product_id);
void app_remove_from_cart(uint32_t product_id);
void app_update_quantity(uint32_t product_id, uint32_t quantity);
void app_clear_cart(void);
uint32_t app_get_cart_count(void);
uint32_t app_get_cart_total(void);

// Wishlist
void app_toggle_wishlist(uint32_t product_id);
int32_t app_is_in_wishlist(uint32_t product_id);

// Checkout
void app_proceed_to_checkout(void);
void app_place_order(void);
```

## Data Model

### Product
```zig
const Product = struct {
    id: u32,
    name: [64]u8,
    price: u32,        // cents
    category_id: u32,
    rating: f32,
    in_stock: bool,
};
```

### CartItem
```zig
const CartItem = struct {
    product_id: u32,
    quantity: u32,
};
```

## License

MIT License
