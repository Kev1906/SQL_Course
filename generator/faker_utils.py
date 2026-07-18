import random
from faker import Faker
from generator.config import SEED

# Initialize seeded Faker instances
fake = Faker()
Faker.seed(SEED)
random.seed(SEED)

def generate_sku(category_name, product_id):
    """Generates a clean product SKU following the pattern: CAT-PROD-ID"""
    cat_prefix = "".join([w[0] for w in category_name.split() if w.isalnum()]).upper()[:3]
    if len(cat_prefix) < 3:
        cat_prefix = (cat_prefix + "XYZ")[:3]
    return f"{cat_prefix}-{SEED}-{product_id:05d}"

def generate_phone():
    """Generates a valid phone number conforming to core.phone_type constraint"""
    # Matches: ^\+?[0-9\s\-()]{7,25}$
    prefix = random.choice(["", "+1", "+34", "+52", "+44", "+49"])
    body = "".join(str(random.randint(0, 9)) for _ in range(8))
    # format: +34-92736481
    if prefix:
        return f"{prefix}-{body[:4]}-{body[4:]}"
    return f"{body[:4]}-{body[4:]}"

def generate_invoice_number(order_id, year=2025):
    """Generates a valid invoice number matching: ^INV-\d{4}-\d{8}$"""
    return f"INV-{year}-{order_id:08d}"

def generate_tracking_number(shipment_id):
    """Generates tracking number conforming to ^[A-Z0-9-]{12,24}$"""
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    random_str = "".join(random.choice(chars) for _ in range(12))
    return f"TRK-{shipment_id:04d}-{random_str}"
