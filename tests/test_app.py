import pytest
from app import app


@pytest.fixture
def client():
    """Create a test client for the Flask app"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_homepage(client):
    """Test that homepage returns 200"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'<!DOCTYPE html>' in response.data


def test_presentation_page(client):
    """Test that presentation page returns 200"""
    response = client.get('/presentation')
    assert response.status_code == 200


def test_galerie_page(client):
    """Test that galerie page returns 200"""
    response = client.get('/galerie')
    assert response.status_code == 200


def test_services_page(client):
    """Test that services page returns 200"""
    response = client.get('/services')
    assert response.status_code == 200


def test_menu_page(client):
    """Test that menu page returns 200"""
    response = client.get('/menu')
    assert response.status_code == 200


def test_404_page(client):
    """Test that 404 page is returned for unknown routes"""
    response = client.get('/page-inexistante')
    assert response.status_code == 404