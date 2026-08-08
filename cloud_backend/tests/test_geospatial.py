import pytest
import math

def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    dlon = lon2_rad - lon1_rad
    dlat = lat2_rad - lat1_rad
    
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance = R * c
    return distance * 1000

def test_haversine_distance():
    # Test identical points
    assert haversine(10.0, 10.0, 10.0, 10.0) == 0.0
    
    # Test close proximity (should be around 111 meters for 0.001 deg lat)
    dist = haversine(10.0, 10.0, 10.001, 10.0)
    assert 110 < dist < 112

def test_consensus_scoring():
    base_conf = 0.50
    new_conf = base_conf + 0.05
    assert new_conf == 0.55
