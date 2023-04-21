import json
import pytest
from main import app, db
from datetime import datetime

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://csye6225:123456@localhost:5432/cloudwebapp'
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
        yield client
        with app.app_context():
            db.session.remove()
            db.drop_all()

def test_userSignup(client):
    # Test creating a user
    user_data = { 
        "first_name": "Jane",
        "last_name": "Doe",
        "password": "somepassword",
        "email": "jane.doe@example.com",
        "account_created": datetime.now(),
        "account_updated": datetime.now()
        }
    response = client.post('/v1/user', json=user_data)
    assert response.status_code == 200