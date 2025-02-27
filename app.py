from flask import Flask, render_template, request, redirect, url_for, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from models import db, User
from werkzeug.security import generate_password_hash, check_password_hash
from os import environ
from dotenv import load_dotenv
import logging
import boto3
from botocore.exceptions import ClientError
from datetime import datetime
import watchtower
import logging.handlers
from email_service import EmailService

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Initialize email service
email_service = EmailService()

# Configure CloudWatch logging
try:
    cloudwatch_handler = watchtower.CloudWatchLogHandler(
        log_group='/flask-app/application',
        stream_name=datetime.now().strftime('%Y-%m-%d-%H-%M-%S'),
        boto3_client=boto3.client('logs', region_name='us-east-1'),
        create_log_group=True
    )
    logger.addHandler(cloudwatch_handler)
    logger.info("CloudWatch logging configured successfully")
except Exception as e:
    logger.error(f"Failed to configure CloudWatch logging: {str(e)}")
    cloudwatch_handler = None

# Add CloudWatch logging to Flask
app = Flask(__name__)
if cloudwatch_handler:
    app.logger.addHandler(cloudwatch_handler)

def get_ssm_parameter(param_name, with_decryption=False):
    """
    Get a parameter from AWS Systems Manager Parameter Store
    """
    try:
        ssm = boto3.client('ssm', region_name='us-east-1')
        response = ssm.get_parameter(
            Name=param_name,
            WithDecryption=with_decryption
        )
        return response['Parameter']['Value']
    except ClientError as e:
        logger.error(f"Failed to get parameter {param_name}: {str(e)}")
        return None

# Get database credentials from SSM
db_user = get_ssm_parameter('/flask-app/db/username')
db_pass = get_ssm_parameter('/flask-app/db/password', with_decryption=True)
db_host = get_ssm_parameter('/flask-app/db/host')
db_port = get_ssm_parameter('/flask-app/db/port')
db_name = get_ssm_parameter('/flask-app/db/name')
flask_secret = get_ssm_parameter('/flask-app/secret-key', with_decryption=True)

# Load environment variables
load_dotenv()

app.secret_key = flask_secret or environ.get('FLASK_SECRET_KEY')

# Database configuration
db_host = db_host or environ.get('DB_HOST', 'localhost')
db_port = db_port or environ.get('DB_PORT', '5432')
db_name = db_name or environ.get('DB_NAME', 'flaskapp')
db_user = db_user or environ.get('DB_USERNAME', 'postgres')
db_pass = db_pass or environ.get('DB_PASSWORD', '')

# Log database connection details (excluding password)
logger.info(f"Connecting to database at {db_host}:{db_port}/{db_name} as {db_user}")

# Test database connection
try:
    engine = db.create_engine(f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}")
    connection = engine.connect()
    connection.close()
    logger.info("Database connection test successful")
except Exception as e:
    logger.error(f"Database connection test failed: {str(e)}", exc_info=True)
    raise

app.config['SQLALCHEMY_DATABASE_URI'] = (
    f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize extensions
db.init_app(app)

# Initialize Flask-Login
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'landing'

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/')
def landing():
    if current_user.is_authenticated:
        return redirect(url_for('home'))
    return render_template('landing.html')

@app.route('/home')
@login_required
def home():
    return render_template('home.html')

@app.route('/login/', methods=['GET', 'POST'])
def login():
    logger.debug("Login route accessed")
    if request.method == 'POST':
        logger.debug("Processing login form")
        username = request.form['username']
        password = request.form['password']
        
        logger.debug(f"Attempting login for user: {username}")
        user = User.query.filter_by(username=username).first()
        
        try:
            if user and check_password_hash(user.password, password):
                logger.debug(f"Login successful for user: {username}")
                login_user(user)
                return redirect(url_for('home'))
            logger.debug(f"Login failed for user: {username}")
            flash('Invalid username or password')
        except Exception as e:
            logger.error(f"Error during login: {str(e)}", exc_info=True)
            db.session.rollback()
            flash('An error occurred during login. Please try again.', 'error')
    
    return render_template('login.html')

@app.route('/register/', methods=['GET', 'POST'])
def register():
    logger.debug(f"Register route accessed with method: {request.method}")
    if request.method == 'POST':
        logger.debug("Processing registration form")
        username = request.form['username']
        password = request.form['password']
        email = request.form['email']
        
        try:
            if User.query.filter_by(username=username).first():
                logger.debug(f"Username {username} already exists")
                flash('Username already exists')
                return redirect(url_for('register'))

            hashed_password = generate_password_hash(password)
            new_user = User(username=username, password=hashed_password, email=email)
            db.session.add(new_user)
            db.session.commit()
            logger.debug(f"User {username} registered successfully")

            # Send welcome email
            welcome_subject = "Welcome to Flask App!"
            welcome_text = f"""
                Hi {username},
                
                Welcome to Flask App! Your account has been successfully created.
                
                Best regards,
                Flask App Team
            """
            welcome_html = f"""
                <h2>Welcome to Flask App!</h2>
                <p>Hi {username},</p>
                <p>Welcome to Flask App! Your account has been successfully created.</p>
                <p>Best regards,<br>Flask App Team</p>
            """
            
            if email_service.send_email(email, welcome_subject, welcome_text, welcome_html):
                logger.info(f"Welcome email sent to {email}")
            else:
                flash("Account created successfully! However, we couldn't send the welcome email. "
                      "You can still proceed to login.", 'warning')

            flash('Registration successful! Please login.', 'success')
            return redirect(url_for('login'))
        except Exception as e:
            logger.error(f"Error during registration: {str(e)}", exc_info=True)
            db.session.rollback()
            flash('An error occurred during registration. Please try again.', 'error')

    return render_template('register.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/test-ssm')
def test_ssm():
    if not current_user.is_authenticated:
        return {"error": "Unauthorized"}, 401
        
    return {
        "db_host": db_host,
        "db_port": db_port,
        "db_name": db_name,
        "db_user": db_user,
        "connected": db.session.is_active
    }

@app.route('/users')
@login_required
def list_users():
    try:
        users = User.query.all()
        logger.info(f"Users: {users}")
        return render_template('users.html', users=users)
    except Exception as e:
        logger.error(f"Error fetching users: {str(e)}")
        flash('Error fetching users list')
        return redirect(url_for('home'))

@app.route('/users/delete/<int:user_id>', methods=['POST'])
@login_required
def delete_user(user_id):
    try:
        # Prevent users from deleting themselves
        if current_user.id == user_id:
            flash('You cannot delete your own account.', 'error')
            return redirect(url_for('list_users'))

        user = User.query.get_or_404(user_id)
        username = user.username
        db.session.delete(user)
        db.session.commit()
        
        logger.info(f"User {username} (ID: {user_id}) deleted by {current_user.username}")
        flash(f'User {username} has been deleted successfully.', 'success')
    except Exception as e:
        logger.error(f"Error deleting user {user_id}: {str(e)}")
        db.session.rollback()
        flash('An error occurred while deleting the user.', 'error')
    
    return redirect(url_for('list_users'))

# Create database tables
def init_db():
    with app.app_context():
        try:
            db.create_all()
            logger.info("Database tables created successfully")
        except Exception as e:
            logger.error(f"Error creating database tables: {str(e)}", exc_info=True)
            raise

# Add request logging middleware
@app.before_request
def log_request_info():
    logger.info('Request: %s %s', request.method, request.url)
    logger.debug('Headers: %s', dict(request.headers))
    if request.method in ['POST', 'PUT']:
        logger.debug('Body: %s', request.get_data())

@app.after_request
def log_response_info(response):
    logger.info('Response: %s %s - %s', request.method, request.url, response.status)
    return response

@app.errorhandler(Exception)
def handle_error(error):
    logger.exception('An error occurred: %s', str(error))
    return 'Internal Server Error', 500

@app.errorhandler(404)
def not_found_error(error):
    logger.error(f"Page not found: {request.url}")
    error_message = f"The page '{request.url}' was not found on our server."
    return render_template('404.html', error_message=error_message), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Server error: {error}")
    db.session.rollback()
    error_details = str(error) if app.debug else "We're experiencing technical difficulties."
    return render_template('500.html', error_details=error_details), 500

@app.errorhandler(401)
def unauthorized_error(error):
    logger.error(f"Unauthorized access attempt: {request.url}")
    flash('Please log in to access this page')
    return redirect(url_for('login'))

@app.errorhandler(403)
def forbidden_error(error):
    logger.error(f"Forbidden access attempt: {request.url}")
    flash('You do not have permission to access this page')
    return redirect(url_for('home'))

if __name__ == '__main__':
    init_db()
    app.run(debug=True) 