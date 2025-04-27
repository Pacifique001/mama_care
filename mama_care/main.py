# mama_care/main.py

from firebase_functions import firestore_fn, options
from firebase_admin import initialize_app, firestore, messaging
import google.cloud.firestore

options.set_global_options(region="us-central1", memory=options.MemoryOption.MB_256)

try:
    initialize_app()
    print("Firebase Admin SDK initialized.")
except ValueError as e:
    if "The default Firebase app already exists" not in str(e):
        print(f"Error initializing Firebase Admin SDK: {e}")

firestore_client = firestore.client()

@firestore_fn.on_document_created(document="appointments/{appointmentId}", timeout_sec=60)
def notify_doctor_on_new_appointment(
    event: firestore_fn.Event[firestore_fn.Change | None]
) -> None:
    """
    Listens for new documents created in the 'appointments' collection
    and sends an FCM notification to the specified doctor.
    """
    try:
        appointment_data = event.data
        if appointment_data is None:
            print("No data associated with the event (appointment creation).")
            return

        appointment_id = event.params['appointmentId']
        doctor_id = appointment_data.get("doctorId")
        patient_name = appointment_data.get("patientName", "A patient")

        if not doctor_id:
            print(f"Doctor ID missing in appointment data for {appointment_id}.")
            return

        print(f"New appointment '{appointment_id}' created for doctor '{doctor_id}'.")

        doctor_tokens = []
        try:
            doctor_ref = firestore_client.collection("users").document(doctor_id)
            doctor_doc = doctor_ref.get()

            if not doctor_doc.exists:
                print(f"Doctor user document '{doctor_id}' not found.")
                return

            doctor_data = doctor_doc.to_dict()
            if doctor_data and "fcmTokens" in doctor_data and isinstance(doctor_data["fcmTokens"], list):
                doctor_tokens = [token for token in doctor_data["fcmTokens"] if token and isinstance(token, str)]

        except Exception as e:
            print(f"Error fetching doctor '{doctor_id}' document: {e}")
            return

        if not doctor_tokens:
            print(f"No valid FCM tokens found for doctor '{doctor_id}'.")
            return

        print(f"Found {len(doctor_tokens)} tokens for doctor '{doctor_id}'.")

        notification = messaging.Notification(
            title="New Appointment Request",
            body=f"{patient_name} requested an appointment.",
        )

        message_data = {
            "type": "appointment_request",
            "appointmentId": appointment_id,
            "route": "/doctor/dashboard",
            "patientId": appointment_data.get("patientId", ""),
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
        }

        message = messaging.MulticastMessage(
            notification=notification,
            data=message_data,
            tokens=doctor_tokens,
             android=messaging.AndroidConfig(
                 priority="high",
                 notification=messaging.AndroidNotification(
                     channel_id="mama_care_high_importance_channel",
                     sound='default',
                     # icon='@mipmap/ic_launcher',
                     # color='#E91E63',
                 ),
             ),
             apns=messaging.APNSConfig(
                 headers={"apns-priority": "10"},
                 payload=messaging.APNSPayload(
                     aps=messaging.Aps(
                         sound="default",
                         badge=1,
                         content_available=True,
                     ),
                 ),
             ),
        )

        try:
            print(f"Sending FCM multicast message to {len(doctor_tokens)} tokens for doctor '{doctor_id}'...")
            batch_response = messaging.send_multicast(message)
            print(f"FCM send completed. Success count: {batch_response.success_count}, Failure count: {batch_response.failure_count}")

            tokens_to_remove = []
            for idx, response in enumerate(batch_response.responses):
                if not response.success:
                    print(f"  Error sending to token {idx+1} ({doctor_tokens[idx][:10]}...): {response.exception}")
                    error_code = getattr(response.exception, 'code', None)
                    if error_code in (
                        "messaging/invalid-registration-token",
                        "messaging/registration-token-not-registered",
                        "messaging/mismatched-credential",
                    ):
                        tokens_to_remove.append(doctor_tokens[idx])

            if tokens_to_remove:
                print(f"Found {len(tokens_to_remove)} invalid tokens to remove for doctor '{doctor_id}'.")
                firestore_client.collection("users").document(doctor_id).update({
                    "fcmTokens": firestore.ArrayRemove(tokens_to_remove)
                })
                print(f"Attempted to remove invalid tokens for doctor '{doctor_id}'.")

        except Exception as e:
            print(f"Error sending FCM message for appointment '{appointment_id}': {e}")

    except Exception as e:
        print(f"General error processing appointment '{event.params.get('appointmentId', 'N/A')}': {e}")