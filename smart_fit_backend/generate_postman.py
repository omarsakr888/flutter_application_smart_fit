import json
import uuid
import datetime

# --- ENVIRONMENT ---
env_data = {
    "id": str(uuid.uuid4()),
    "name": "SmartFit_Environment",
    "values": [
        {"key": "base_url", "value": "http://localhost:5000", "type": "default", "enabled": True},
        {"key": "jwt_token", "value": "", "type": "secret", "enabled": True},
        {"key": "user_email", "value": "test@smartfit.app", "type": "default", "enabled": True},
        {"key": "user_password", "value": "SecurePassword123!", "type": "secret", "enabled": True},
        {"key": "scan_id", "value": "", "type": "default", "enabled": True}
    ],
    "_postman_variable_scope": "environment",
    "_postman_exported_at": datetime.datetime.utcnow().isoformat(),
    "_postman_exported_using": "Postman/10.0.0"
}

with open("SmartFit_Environment.json", "w") as f:
    json.dump(env_data, f, indent=4)


# --- COLLECTION ---
def make_request(name, method, url_path, auth_req=True, body=None, test_script=None):
    req = {
        "name": name,
        "event": [],
        "request": {
            "method": method,
            "header": [],
            "url": {
                "raw": f"{{{{base_url}}}}{url_path}",
                "host": ["{{base_url}}"],
                "path": url_path.strip("/").split("/")
            }
        },
        "response": []
    }
    
    if auth_req:
        req["request"]["auth"] = {
            "type": "bearer",
            "bearer": [{"key": "token", "value": "{{jwt_token}}", "type": "string"}]
        }
        
    if body:
        req["request"]["header"].append({"key": "Content-Type", "value": "application/json"})
        req["request"]["body"] = {
            "mode": "raw",
            "raw": json.dumps(body, indent=4)
        }
        
    if test_script:
        req["event"].append({
            "listen": "test",
            "script": {
                "exec": test_script.strip().split("\n"),
                "type": "text/javascript"
            }
        })
        
    return req

# Auth tests
test_login = """
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});
var jsonData = pm.response.json();
pm.test("JWT Token returned", function() {
    pm.expect(jsonData.access_token).to.not.be.undefined;
});
if (jsonData.access_token) {
    pm.environment.set("jwt_token", jsonData.access_token);
}
"""

test_200 = """
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});
"""

test_register = """
pm.test("Status code is 200 or 201", function () {
    pm.expect(pm.response.code).to.be.oneOf([200, 201]);
});
"""

collection = {
    "info": {
        "_postman_id": str(uuid.uuid4()),
        "name": "SmartFit_Collection",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    },
    "item": [
        {
            "name": "1. Authentication",
            "item": [
                make_request("Register User", "POST", "/auth/register", False, {"email": "{{user_email}}", "password": "{{user_password}}", "name": "QA Tester"}, test_register),
                make_request("Login & Capture JWT", "POST", "/auth/login", False, {"email": "{{user_email}}", "password": "{{user_password}}"}, test_login),
                make_request("Test Invalid Token (401)", "GET", "/users/profile", False, None, "pm.test('Status is 401', function(){pm.response.to.have.status(401);});\npm.test('Error message present', function(){pm.expect(pm.response.json().message).to.include('Authentication required');});"),
            ]
        },
        {
            "name": "2. OCR Flow",
            "item": [
                make_request("Confirm OCR Extraction", "POST", "/ocr/confirm", True, {"scan_id": "{{scan_id}}", "fields": {"Age": {"value": 25, "source": "manual"}, "Gender": {"value": "M", "source": "manual"}}}, test_200),
                make_request("OCR History", "GET", "/ocr/history", True, None, test_200),
            ]
        },
        {
            "name": "3. Plan Generation",
            "item": [
                make_request("Generate Plan (Fat Loss)", "POST", "/api/v1/generate-plan", True, {"Age": 25, "Height": 180, "Weight": 90, "Gender": "M", "SMM_(Skeletal_Muscle_Mass)": 38, "PBF_(Percent_Body_Fat)": 25}, test_200),
                make_request("Validation Error (422)", "POST", "/api/v1/generate-plan", True, {"Age": -5}, "pm.test('Status is 422', function(){pm.response.to.have.status(422);});"),
            ]
        },
        {
            "name": "4. Dashboard & Logging",
            "item": [
                make_request("Get Dashboard", "GET", "/users/dashboard", True, None, test_200),
                make_request("Log Hydration", "POST", "/users/log-hydration", True, {"cups": 2}, test_200),
                make_request("Get Profile", "GET", "/users/profile", True, None, test_200),
                make_request("Save Preferences", "POST", "/users/preferences", True, {"diet_type": "Keto", "preferred_days": 5, "hydration_enabled": True, "sleep_enabled": True}, test_200),
            ]
        },
        {
            "name": "5. Rate Limits & Reliability",
            "item": [
                make_request("Rate Limit Test (Spam API)", "GET", "/health", False, None, "pm.test('Status is 200 or 429', function(){pm.expect(pm.response.code).to.be.oneOf([200, 429]);});")
            ]
        }
    ]
}

with open("SmartFit_Collection.json", "w") as f:
    json.dump(collection, f, indent=4)

print("Collection and Environment generated successfully.")
