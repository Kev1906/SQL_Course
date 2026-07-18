import pandas as pd
from generator.generate.utils import save_to_csv

def generate_countries():
    # 100 realistic countries spanning various regions
    countries_data = [
        # North America (10)
        ("US", "United States", "North America"),
        ("CA", "Canada", "North America"),
        ("MX", "Mexico", "North America"),
        ("CR", "Costa Rica", "North America"),
        ("PA", "Panama", "North America"),
        ("JM", "Jamaica", "North America"),
        ("DO", "Dominican Republic", "North America"),
        ("GT", "Guatemala", "North America"),
        ("HN", "Honduras", "North America"),
        ("SV", "El Salvador", "North America"),
        
        # South America (12)
        ("BR", "Brazil", "South America"),
        ("AR", "Argentina", "South America"),
        ("CO", "Colombia", "South America"),
        ("CL", "Chile", "South America"),
        ("PE", "Peru", "South America"),
        ("VE", "Venezuela", "South America"),
        ("EC", "Ecuador", "South America"),
        ("BO", "Bolivia", "South America"),
        ("UY", "Uruguay", "South America"),
        ("PY", "Paraguay", "South America"),
        ("GY", "Guyana", "South America"),
        ("SR", "Suriname", "South America"),
        
        # Europe (35)
        ("GB", "United Kingdom", "Europe"),
        ("DE", "Germany", "Europe"),
        ("FR", "France", "Europe"),
        ("IT", "Italy", "Europe"),
        ("ES", "Spain", "Europe"),
        ("NL", "Netherlands", "Europe"),
        ("BE", "Belgium", "Europe"),
        ("CH", "Switzerland", "Europe"),
        ("SE", "Sweden", "Europe"),
        ("NO", "Norway", "Europe"),
        ("DK", "Denmark", "Europe"),
        ("FI", "Finland", "Europe"),
        ("IE", "Ireland", "Europe"),
        ("AT", "Austria", "Europe"),
        ("PT", "Portugal", "Europe"),
        ("GR", "Greece", "Europe"),
        ("PL", "Poland", "Europe"),
        ("CZ", "Czech Republic", "Europe"),
        ("HU", "Hungary", "Europe"),
        ("RO", "Romania", "Europe"),
        ("BG", "Bulgaria", "Europe"),
        ("SK", "Slovakia", "Europe"),
        ("HR", "Croatia", "Europe"),
        ("UA", "Ukraine", "Europe"),
        ("RU", "Russia", "Europe"),
        ("TR", "Turkey", "Europe"),
        ("EE", "Estonia", "Europe"),
        ("LV", "Latvia", "Europe"),
        ("LT", "Lithuania", "Europe"),
        ("SI", "Slovenia", "Europe"),
        ("CY", "Cyprus", "Europe"),
        ("LU", "Luxembourg", "Europe"),
        ("MT", "Malta", "Europe"),
        ("IS", "Iceland", "Europe"),
        ("AL", "Albania", "Europe"),
        
        # Asia (25)
        ("JP", "Japan", "Asia"),
        ("CN", "China", "Asia"),
        ("IN", "India", "Asia"),
        ("KR", "South Korea", "Asia"),
        ("SG", "Singapore", "Asia"),
        ("MY", "Malaysia", "Asia"),
        ("TH", "Thailand", "Asia"),
        ("ID", "Indonesia", "Asia"),
        ("VN", "Vietnam", "Asia"),
        ("PH", "Philippines", "Asia"),
        ("PK", "Pakistan", "Asia"),
        ("BD", "Bangladesh", "Asia"),
        ("IL", "Israel", "Asia"),
        ("SA", "Saudi Arabia", "Asia"),
        ("AE", "United Arab Emirates", "Asia"),
        ("QA", "Qatar", "Asia"),
        ("KW", "Kuwait", "Asia"),
        ("OM", "Oman", "Asia"),
        ("JO", "Jordan", "Asia"),
        ("LB", "Lebanon", "Asia"),
        ("KZ", "Kazakhstan", "Asia"),
        ("LK", "Sri Lanka", "Asia"),
        ("NP", "Nepal", "Asia"),
        ("MM", "Myanmar", "Asia"),
        ("KH", "Cambodia", "Asia"),
        
        # Africa (15)
        ("ZA", "South Africa", "Africa"),
        ("EG", "Egypt", "Africa"),
        ("NG", "Nigeria", "Africa"),
        ("KE", "Kenya", "Africa"),
        ("MA", "Morocco", "Africa"),
        ("DZ", "Algeria", "Africa"),
        ("TN", "Tunisia", "Africa"),
        ("GH", "Ghana", "Africa"),
        ("CI", "Ivory Coast", "Africa"),
        ("ET", "Ethiopia", "Africa"),
        ("UG", "Uganda", "Africa"),
        ("TZ", "Tanzania", "Africa"),
        ("SN", "Senegal", "Africa"),
        ("CM", "Cameroon", "Africa"),
        ("AO", "Angola", "Africa"),
        
        # Oceania (3)
        ("AU", "Australia", "Oceania"),
        ("NZ", "New Zealand", "Oceania"),
        ("FJ", "Fiji", "Oceania")
    ]
    
    # Pad to exactly 100 if we missed any, but let's count:
    # 10 + 12 + 35 + 25 + 15 + 3 = 100.
    # Total is exactly 100! Excellent.
    
    df = pd.DataFrame(countries_data, columns=["code", "name", "region"])
    # ID starts at 1, automatically incremented by identity, but for Python generation 
    # and tracking foreign keys it is useful to have a clear 1-indexed order.
    # PostgreSQL COPY will take the CSV without ID column since DB generates it,
    # OR we can generate IDs in the CSV and copy them explicitly (identity ALWAYS overrides,
    # unless we use COPY with ID or let the database manage it. Wait!
    # If the database table is defined as GENERATED ALWAYS AS IDENTITY,
    # PostgreSQL's COPY statement can import the ID column directly because COPY bypasses the identity generator constraint
    # OR we can omit the ID column in the CSV and let the DB generate it.
    # If we omit the ID in the CSV, how will our Python script track foreign keys?
    # Our Python script can track the IDs since we know they are generated 1 to N sequentially!
    # So we can keep IDs in the CSV and write them, and PostgreSQL COPY will import them.
    # Yes! Let's write the `id` column in the CSV. That is very robust because it matches
    # the 1-indexed mapping in Python.
    
    df.insert(0, "id", range(1, len(df) + 1))
    save_to_csv(df, "countries.csv")
    return df

if __name__ == "__main__":
    generate_countries()
