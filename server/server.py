import xmlrpc.client
from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import base64

app = Flask(__name__)
CORS(app)

url = ''
db = ''
username = ''
password = ''

# Helper function to log errors
def log_error(message):
    app.logger.error(message)
    print(message)  # Also print to console for debugging purposes

@app.route('/store-data', methods=['POST'])
def store_data():
    global url, db, username, password
    try:
        data = request.json
        url = data['url']
        db = data['db']
        username = data['username']
        password = data['password']

        print (url)
        print (db)
        print (username)
        print (password)

        return 'Data stored successfully', 200
    except Exception as e:
        log_error(f"Error storing data: {e}")
        return jsonify({'error': 'Error storing data', 'message': str(e)}), 500

@app.route('/get-data', methods=['GET'])
def get_data():
    global url, db, username, password
    data = {
        'url': url,
        'db': db,
        'username': username,
        'password': password,
    }
    return jsonify(data), 200

@app.route('/test-database-api', methods=['GET'])
def test_database_api():
    global url
    try:
        if not url:
            raise ValueError("URL is not set or invalid")

        info = xmlrpc.client.ServerProxy(f'{url}/start').start()
        return jsonify(info), 200
    except xmlrpc.client.ProtocolError as e:
        log_error(f"ProtocolError connecting to {url}/start: {e}")
        return jsonify({'error': 'ProtocolError', 'message': str(e)}), 500
    except xmlrpc.client.Fault as e:
        log_error(f"XML-RPC Fault connecting to {url}/start: {e}")
        return jsonify({'error': 'XML-RPC Fault', 'message': str(e)}), 500
    except ValueError as e:
        log_error(f"ValueError: {e}")
        return jsonify({'error': 'ValueError', 'message': str(e)}), 400
    except Exception as e:
        log_error(f"Unexpected error connecting to {url}/start: {e}")
        return jsonify({'error': 'UnexpectedError', 'message': str(e)}), 500

@app.route('/login-api', methods=['POST'])
def login_api():
    global url
    data = request.json
    url = data['url']
    
    try:
        common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
        version = common.version()

        db_methods = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/db')
        dbs = db_methods.list()

        return jsonify({'version': version, 'databases': dbs}), 200
    
    except xmlrpc.client.ProtocolError as e:
        app.logger.error(f"ProtocolError connecting to {url}/xmlrpc/2/common: {e}")
        return jsonify({'error': 'ProtocolError', 'message': str(e)}), 500
    
    except Exception as e:
        app.logger.error(f"Error verifying server URL: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/authenticate-api', methods=['GET'])
def authenticate_api():
    global url, db, username, password
    try:
        common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
        uid = common.authenticate(db, username, password, {})
        print(type(uid))
        print(uid)
        if uid:
            return jsonify({'status': 'success', 'uid': uid}), 200
        else:
            return jsonify({'status': 'failed', 'message': 'Failed authentication'}), 401
    except xmlrpc.client.ProtocolError as e:
        log_error(f"ProtocolError connecting to {url}/xmlrpc/2/common: {e}")
        return jsonify({'status': 'failed', 'message': str(e)}), 500
    except Exception as e:
        log_error(f"Error connecting to {url}/xmlrpc/2/common: {e}")
        return jsonify({'status': 'failed', 'message': str(e)}), 500

@app.route('/fetch-tasks', methods=['GET'])
def fetch_tasks():
    global url, db, username, password
    try:
        if not url or not db:
            raise ValueError("URL or DB is not set or invalid")

        common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
        models = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/object')

        user_id = common.authenticate(db, username, password, {})
        if not user_id:
            return jsonify({'error': 'Authentication failed'}), 401

        task_ids = models.execute_kw(db, user_id, password, 'project.task', 'search', [[['user_ids', 'in', [user_id]]]])
        tasks = models.execute_kw(db, user_id, password, 'project.task', 'read', [task_ids],
                                  {'fields': ['name', 'description', 'project_id', 'tag_ids', 'date_deadline', 'user_ids', 'planned_hours', 'create_date', 'priority', 'stage_id', 'remaining_hours', 'kanban_state']})

        if not tasks:
            return jsonify({'message': 'No tasks found for the authenticated user'}), 404

        for task in tasks:
            activity_ids = models.execute_kw(db, user_id, password, 'mail.activity', 'search',
                                             [[['res_id', '=', task['id']], ['res_model', '=', 'project.task']]])
            activities = models.execute_kw(db, user_id, password, 'mail.activity', 'read', [activity_ids],
                                           {'fields': ['id', 'summary', 'activity_type_id', 'date_deadline', 'user_id', 'note']})

            task['activities'] = activities

        project_ids = list(set(task['project_id'][0] for task in tasks))
        stages_by_project = {}
        for project_id in project_ids:
            stages = models.execute_kw(db, user_id, password,
                                       'project.task.type', 'search_read',
                                       [[['project_ids', 'in', [project_id]]]],
                                       {'fields': ['id', 'name']}
                                       )
            stages_by_project[project_id] = [stage['name'] for stage in stages]

        tag_ids = list(set(tag_id for task in tasks for tag_id in task['tag_ids']))
        tags = models.execute_kw(db, user_id, password, 'project.tags', 'read', [tag_ids], {'fields': ['name']})
        tag_map = {tag['id']: tag['name'] for tag in tags}

        for task in tasks:
            project_id = task['project_id'][0]
            if project_id in stages_by_project:
                task['stages'] = stages_by_project[project_id]

            task['tag_names'] = [tag_map[tag_id] for tag_id in task['tag_ids']]

        app.logger.info(f"Tasks fetched successfully: {tasks}")
        return jsonify(tasks), 200

    except xmlrpc.client.ProtocolError as e:
        log_error(f"ProtocolError connecting to {url}/xmlrpc/2/object: {e}")
        return jsonify({'error': 'ProtocolError', 'message': str(e)}), 500

    except Exception as e:
        log_error(f"Error fetching tasks: {e}")
        return jsonify({'error': 'Error fetching tasks', 'message': str(e)}), 500

@app.route('/fetch-apps', methods=['GET'])
def fetch_apps():
    global url, db, username, password
    try:
        # Connect to Odoo XML-RPC
        common_endpoint = '{}/xmlrpc/2/common'.format(url)
        object_endpoint = '{}/xmlrpc/2/object'.format(url)
        common = xmlrpc.client.ServerProxy(common_endpoint)
        uid = common.authenticate(db, username, password, {})
        
        if uid:
            models = xmlrpc.client.ServerProxy(object_endpoint)
            module_ids = models.execute_kw(db, uid, password,
                                           'ir.module.module', 'search_read',
                                           [[('state', '=', 'installed')]],
                                           {'fields': ['name']}
                                           )
            active_apps = [module['name'] for module in module_ids]
            print (active_apps)
            return jsonify({'active_apps': active_apps}), 200
        else:
            return jsonify({'error': 'Authentication failed'}), 401
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/update-stage', methods=['POST'])
def update_stage():

    global url, db, username, password

    common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
    uid = common.authenticate(db, username, password, {})

    models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

    try:
        data = request.get_json()
        task_id = data.get('task_id')
        new_stage_name = data.get('new_stage_name')

        if not task_id or not new_stage_name:
            return jsonify({'success': False, 'error': 'Missing task_id or new_stage_name'}), 400

        # Fetch the stage ID based on the stage name
        stage_ids = models.execute_kw(db, uid, password,
            'project.task.type', 'search', [[['name', '=', new_stage_name]]])
        
        if not stage_ids:
            return jsonify({'success': False, 'error': 'Stage not found'}), 404

        new_stage_id = stage_ids[0]

        # Update the task stage
        result = models.execute_kw(db, uid, password, 'project.task', 'write', [[task_id], {'stage_id': new_stage_id}])

        if result:
            return jsonify({'success': True}), 200
        else:
            return jsonify({'success': False, 'error': 'Failed to update task'}), 500

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/isadmin', methods=['GET'])
def isadmin():
    global url, db, username, password

    try:
        # Authenticate user
        common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
        uid = common.authenticate(db, username, password, {})

        if uid is None:
            print('Failed to authenticate user')
            return jsonify({'error': 'Failed to authenticate user'}), 401

        print(f'Authenticated user with uid: {uid}')

        # Initialize the object connection
        models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

        # Fetch the user details
        user = models.execute_kw(db, uid, password, 'res.users', 'read', [uid], {'fields': ['id', 'groups_id']})
        if not user:
            print('User not found')
            return jsonify({'error': 'User not found'}), 404

        user = user[0]
        group_ids = user['groups_id']
        print(f'User group IDs: {group_ids}')

        # Fetch all groups to find the correct administrator group name
        all_groups = models.execute_kw(db, uid, password, 'res.groups', 'search_read', [[], ['name']])
        admin_group_ids = [group['id'] for group in all_groups if group['name'] == 'Administrator']

        if not admin_group_ids:
            print('Administrator group not found')
            return jsonify({'is_admin': False})

        print(f'Administrator group IDs: {admin_group_ids}')

        # Check if the user is in any of the Administrator groups
        is_admin = any(admin_group_id in group_ids for admin_group_id in admin_group_ids)
        print(f'The user {"is" if is_admin else "is not"} an administrator')
        return jsonify({'is_admin': is_admin}), 200

    except Exception as e:
        print(f'An error occurred: {str(e)}')
        return jsonify({'error': 'An error occurred'}), 500
    
@app.route('/fetch-new-task', methods=['GET'])
def fetch_new_task():
    global url, db, username, password

    try:
        # Authenticate the user
        common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
        uid = common.authenticate(db, username, password, {})

        if uid:
            models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

            # Fetch projects related to the authenticated user
            projects = models.execute_kw(db, uid, password,
                                         'project.project', 'search_read',
                                         [[('user_id', '=', uid)]],
                                         {'fields': ['name']})

            project_data = []
            for project in projects:
                project_name = project['name']
                project_id = project['id']
                
                # Fetch tasks for the project
                tasks = models.execute_kw(db, uid, password,
                                          'project.task', 'search_read',
                                          [[('project_id', '=', project_id)]],
                                          {'fields': ['name']})
                task_names = [task['name'] for task in tasks]

                # Fetch stages for the project
                stages = models.execute_kw(db, uid, password,
                                           'project.task.type', 'search_read',
                                           [[('project_ids', 'in', project_id)]],
                                           {'fields': ['name']})
                stage_names = [stage['name'] for stage in stages]

                project_data.append({
                    'Project': project_name,
                    'Tasks': task_names,
                    'Stages': stage_names
                })

            # Fetch users related to the Odoo instance
            users = models.execute_kw(db, uid, password,
                                      'res.users', 'search_read',
                                      [[('active', '=', True)]],
                                      {'fields': ['name']})

            user_data = [{'name': user['name']} for user in users]

            print('Projects:', project_data)
            print('Users:', user_data)

            return jsonify({'projects': project_data, 'users': user_data})
        else:
            print('Failed to authenticate user')
            return jsonify({'error': 'Failed to authenticate user'})

    except Exception as e:
        print('Error:', str(e))
        return jsonify({'error': str(e)})
    
def create_task_in_odoo(task_data):
    global url, username, password

    data = request.json

    task_name = data.get('task_name')
    project_name = data.get('project_name')
    stage_name = data.get('stage_name')
    user_name = data.get('user_name')
    priority = data.get('priority')
    deadline = data.get('deadline')

    # Authenticate
    common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
    uid = common.authenticate(db, username, password, {})
    print(uid)
    if uid:
        models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))
        
        # Fetch project ID
        project_id = models.execute_kw(db, uid, password, 'project.project', 'search', [[['name', '=', project_name]]])
        if not project_id:
            print(f"Project '{project_name}' not found.")
            exit()
        
        # Fetch stage ID
        stage_id = models.execute_kw(db, uid, password, 'project.task.type', 'search', [[['name', '=', stage_name], ['project_ids', 'in', project_id[0]]]])
        if not stage_id:
            print(f"Stage '{stage_name}' not found in project '{project_name}'.")
            exit()
        
        # Fetch user ID by user name
        user_ids = models.execute_kw(db, uid, password, 'res.users', 'search_read', [[['name', '=', user_name]]], {'fields': ['id']})
        if not user_ids:
            print(f"User '{user_name}' not found.")
            exit()
        user_id = user_ids[0]['id']
        
        # Task details dictionary
        task_details = {
            'name': task_name,
            'project_id': project_id[0],
            'stage_id': stage_id[0],
            'user_ids': [(6, 0, [user_id])],  # Assign user to the task
            'priority': priority,
            'date_deadline': deadline,
        }

        # Create task
        task_id = models.execute_kw(db, uid, password, 'project.task', 'create', [task_details])
        
        if task_id:
            print(f"Task created successfully with ID: {task_id}")
            return True
        else:
            print("Failed to create task.")
            return False
    else:
        print("Failed to authenticate.")
    
@app.route('/add-task', methods=['POST'])
def add_task():
    global url, username, password

    data = request.json

    task_name = data.get('task_name')
    project_name = data.get('project_name')
    stage_name = data.get('stage_name')
    user_name = data.get('user_name')
    priority = data.get('priority')
    deadline = data.get('deadline')

    # Ensure high_priority is '1' or '0'
    if priority not in ['0', '1']:
        return jsonify({'success': False, 'error': 'Invalid priority value'}), 400

    # Example of how to handle the task creation
    try:
        # Create the task in Odoo (example)
        task_data = {
            'name': task_name,
            'project_id': project_name,
            'stage_name': stage_name,
            'user_name': user_name,
            'priority': int(priority),  # Convert to integer 0 or 1
            'deadline': deadline
        }
        # Replace this with actual Odoo task creation code
        result = create_task_in_odoo(task_data)

        if result:
            return jsonify({'success': True}), 200
        else:
            return jsonify({'success': False, 'error': 'Failed to create task'}), 500

    except Exception as e:
        print(f'Error adding task: {e}')
        return jsonify({'success': False, 'error': 'Error adding task'}), 500

@app.route('/fetch-contacts', methods=['GET'])
def fetch_contacts():
    global url, username, password

    # Set up XML-RPC connections
    common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
    models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

    # Authenticate and get user ID
    uid = common.authenticate(db, username, password, {})
    if not uid:
        return jsonify({'error': 'Authentication failed'}), 401

    try:
        # Fetch contacts
        contacts = models.execute_kw(db, uid, password,
            'res.partner', 'search_read',
            [[]],  # domain, empty list means no filter
            {'fields': ['name', 'email', 'phone', 'mobile', 'image_1920']})  # fields to fetch

        # Process contact images
        for contact in contacts:
            if contact.get('image_1920'):
                if isinstance(contact['image_1920'], bytes):
                    # If image is in bytes, encode it to base64
                    contact['image_1920'] = base64.b64encode(contact['image_1920']).decode('utf-8')
                elif isinstance(contact['image_1920'], str):
                    # If image is already a base64 string, no need to encode again
                    contact['image_1920'] = contact['image_1920']
                else:
                    # Handle unexpected data type
                    contact['image_1920'] = None
            else:
                contact['image_1920'] = None

        return jsonify(contacts)

    except xmlrpc.client.Fault as fault:
        print(f"XML-RPC Fault: {fault}")
        return jsonify({'error': str(fault)}), 500
    except Exception as e:
        print(f"An error occurred: {e}")
        return jsonify({'error': str(e)}), 500
    
@app.route('/fetch-timesheet', methods=['GET'])
def fetch_timesheet():
    global url, username, password

    # Set up XML-RPC connections
    common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
    models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

    # Authenticate and get user ID
    uid = common.authenticate(db, username, password, {})
    if not uid:
        return jsonify({'error': 'Authentication failed'}), 401

    try:
        # Fetch tasks assigned to the authenticated user
        tasks = models.execute_kw(db, uid, password,
            'project.task', 'search_read',
            [[['user_ids', 'in', [uid]]]],  # Filter tasks by user ID
            {'fields': ['id', 'name']})  # Fields to fetch

        # Fetch timesheet lines for each task
        tasks_with_timesheets = []
        for task in tasks:
            task_id = task['id']
            timesheet_lines = models.execute_kw(db, uid, password,
                'account.analytic.line', 'search_read',
                [[['task_id', '=', task_id]]],  # Filter timesheet lines by task ID
                {'fields': ['name', 'unit_amount', 'date', 'account_id', 'employee_id']})  # Fields to fetch
            
            task['timesheet_lines'] = timesheet_lines
            tasks_with_timesheets.append(task)
        
        # Print for debugging
        print("tasks_with_timesheets :",tasks_with_timesheets)
        print ("task :",task)

        return jsonify(tasks_with_timesheets)
    except Exception as e:
        print(f"An error occurred: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/add-timesheet-line', methods=['POST'])
def add_timesheet_line():
    global url, username, password

    # Set up XML-RPC connections
    common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
    models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

    # Authenticate and get user ID
    uid = common.authenticate(db, username, password, {})
    if not uid:
        return jsonify({'error': 'Authentication failed'}), 401

    data = request.json
    task_id = data.get('task_id')
    unit_amount = data.get('unit_amount')
    name = data.get('name')  # You may use the task name or any other identifier if needed
    date = data.get('date')

    try:
        # Create a new timesheet line
        models.execute_kw(db, uid, password,
            'account.analytic.line', 'create',
            [{
                'task_id': task_id,
                'unit_amount': unit_amount,
                'name': name,
                'date': date,
            }])
        
        return jsonify({'status': 'Timesheet line added successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)
