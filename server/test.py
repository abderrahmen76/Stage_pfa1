import xmlrpc.client
import base64
from PIL import Image
from io import BytesIO

# Odoo instance information
url = 'http://localhost:8069/'
db = 'test'
username = '123'
password = '123'

# Set up XML-RPC connections
common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

# Authenticate and get user ID
uid = common.authenticate(db, username, password, {})
if not uid:
    raise Exception("Authentication failed")

def fetch_tasks():
    try:
        # Fetch tasks
        tasks = models.execute_kw(db, uid, password,
            'project.task', 'search_read',
            [[]],  # domain, empty list means no filter
            {'fields': ['id', 'name']})  # fields to fetch
        return tasks
    except Exception as e:
        print(f"An error occurred while fetching tasks: {e}")
        return []

def fetch_timesheet_lines(task_id):
    try:
        # Fetch timesheet lines related to a specific task
        timesheet_lines = models.execute_kw(db, uid, password,
            'account.analytic.line', 'search_read',
            [[['task_id', '=', task_id]]],  # domain to filter by task_id
            {'fields': ['name', 'unit_amount', 'date', 'account_id', 'employee_id']})  # fields to fetch
        return timesheet_lines
    except Exception as e:
        print(f"An error occurred while fetching timesheet lines for task {task_id}: {e}")
        return []

def main():
    tasks = fetch_tasks()
    if not tasks:
        print("No tasks found.")
        return

    for task in tasks:
        task_id = task['id']
        task_name = task['name']
        print(f"Task: {task_name} (ID: {task_id})")
        
        timesheet_lines = fetch_timesheet_lines(task_id)
        if not timesheet_lines:
            print(f"No timesheet lines found for task {task_id}.")
        else:
            for line in timesheet_lines:
                print(f" - Timesheet Line: {line['name']}, Hours: {line['unit_amount']}, Date: {line['date']}, Account: {line['account_id'][1] if line.get('account_id') else 'N/A'}, Employee: {line['employee_id'][1] if line.get('employee_id') else 'N/A'}")

if __name__ == '__main__':
    main()