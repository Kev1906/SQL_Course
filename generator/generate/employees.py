import random
import pandas as pd
from datetime import datetime, timedelta
from generator.faker_utils import fake
from generator.generate.utils import save_to_csv
from generator.config import EMPLOYEES_COUNT

def generate_employees_and_departments():
    # 1. Generate 8 corporate departments
    departments_data = [
        {"id": 1, "name": "Executive Board", "budget": 5000000.00, "manager_id": 1}, # CEO manages Exec
        {"id": 2, "name": "Finance", "budget": 1200000.00, "manager_id": 2},
        {"id": 3, "name": "Human Resources", "budget": 800000.00, "manager_id": 3},
        {"id": 4, "name": "Information Technology", "budget": 3000000.00, "manager_id": 4},
        {"id": 5, "name": "Sales & Marketing", "budget": 4000000.00, "manager_id": 5},
        {"id": 6, "name": "Logistics & Warehouse", "budget": 2500000.00, "manager_id": 6},
        {"id": 7, "name": "Customer Support", "budget": 1000000.00, "manager_id": 7},
        {"id": 8, "name": "Product Management", "budget": 1800000.00, "manager_id": 8}
    ]
    
    # Save departments to CSV
    departments_df = pd.DataFrame(departments_data)
    departments_df["manager_id"] = departments_df["manager_id"].astype("Int64")
    save_to_csv(departments_df, "departments.csv")
    
    # 2. Generate 300 employees
    employees = []
    seen_emails = set()
    
    job_titles = {
        1: [("Chief Executive Officer", 250000, 350000)], # Exec Board
        2: [("Finance Director", 120000, 160000), ("Senior Accountant", 75000, 95000), ("Financial Analyst", 55000, 70000), ("Junior Accountant", 45000, 52000)],
        3: [("HR Director", 100000, 130000), ("HR Specialist", 60000, 75000), ("Recruiter", 50000, 65000), ("HR Coordinator", 42000, 48000)],
        4: [("IT Director", 130000, 180000), ("Lead Software Engineer", 110000, 140000), ("Senior Systems Administrator", 90000, 110000), ("Database Administrator", 85000, 105000), ("DevOps Engineer", 80000, 100000), ("Software Engineer", 70000, 90000), ("Helpdesk Specialist", 45000, 55000)],
        5: [("Sales Director", 110000, 150000), ("Marketing Manager", 85000, 105000), ("SEO Specialist", 55000, 68000), ("Account Manager", 60000, 80000), ("Sales Representative", 48000, 62000)],
        6: [("Logistics Director", 100000, 130000), ("Supply Chain Manager", 80000, 98000), ("Logistics Coordinator", 50000, 62000), ("Warehouse Supervisor", 45000, 55000), ("Inventory Clerk", 35000, 42000)],
        7: [("Customer Support Director", 90000, 115000), ("Support Team Lead", 55000, 68000), ("Senior Support Agent", 45000, 52000), ("Support Agent", 35000, 42000)],
        8: [("Product Director", 125000, 165000), ("Senior Product Manager", 100000, 125000), ("Product Manager", 78000, 95000), ("Data Analyst", 60000, 78000)]
    }
    
    # Base start date for company (10 years ago)
    base_date = datetime.now() - timedelta(days=365 * 10)
    
    # Helper to generate unique corporate email
    def make_email(fn, ln):
        base = f"{fn[0].lower()}{ln.lower()}"
        base = "".join(c for c in base if c.isalnum())
        email = f"{base}@datamartx.com"
        counter = 1
        while email in seen_emails:
            email = f"{base}{counter}@datamartx.com"
            counter += 1
        seen_emails.add(email)
        return email

    # Employee 1: CEO (in Dept 1, manages himself/none)
    ceo_fn = fake.first_name()
    ceo_ln = fake.last_name()
    employees.append({
        "id": 1,
        "department_id": 1,
        "manager_id": None,
        "first_name": ceo_fn,
        "last_name": ceo_ln,
        "email": make_email(ceo_fn, ceo_ln),
        "job_title": "Chief Executive Officer",
        "salary": round(random.uniform(280000, 340000), 2),
        "hire_date": (base_date + timedelta(days=random.randint(0, 365))).strftime("%Y-%m-%d"),
        "is_active": True
    })
    
    # Employees 2-8: Department Directors (reporting to CEO, IDs match the manager_ids in departments)
    # Note: Dept 1 manager is Employee 1 (CEO), so we start with Dept 2 for employee 2, etc.
    for dept_id in range(2, 9):
        dir_fn = fake.first_name()
        dir_ln = fake.last_name()
        title_info = job_titles[dept_id][0] # First item is Director
        employees.append({
            "id": dept_id,
            "department_id": dept_id,
            "manager_id": 1, # reports to CEO
            "first_name": dir_fn,
            "last_name": dir_ln,
            "email": make_email(dir_fn, dir_ln),
            "job_title": title_info[0],
            "salary": round(random.uniform(title_info[1], title_info[2]), 2),
            "hire_date": (base_date + timedelta(days=random.randint(365, 365*3))).strftime("%Y-%m-%d"),
            "is_active": True
        })
        
    # Employees 9-300: Staff distributed across departments
    for emp_id in range(9, EMPLOYEES_COUNT + 1):
        dept_id = random.choices(range(2, 9), weights=[8, 8, 20, 20, 24, 10, 10])[0]
        # Manager is the director of this department (emp_id matches dept_id for directors 2-8)
        manager_id = dept_id 
        
        # Pick a job title other than Director
        title_options = job_titles[dept_id][1:]
        title_info = random.choice(title_options)
        
        fn = fake.first_name()
        ln = fake.last_name()
        
        # If active
        is_active = random.random() > 0.08 # 8% turnover/inactive
        
        employees.append({
            "id": emp_id,
            "department_id": dept_id,
            "manager_id": manager_id,
            "first_name": fn,
            "last_name": ln,
            "email": make_email(fn, ln),
            "job_title": title_info[0],
            "salary": round(random.uniform(title_info[1], title_info[2]), 2),
            "hire_date": (base_date + timedelta(days=random.randint(365*2, int(365*9.5)))).strftime("%Y-%m-%d"),
            "is_active": is_active
        })
        
    df = pd.DataFrame(employees)
    df["manager_id"] = df["manager_id"].astype("Int64")
    save_to_csv(df, "employees.csv")
    return departments_df, df

if __name__ == "__main__":
    generate_employees_and_departments()
