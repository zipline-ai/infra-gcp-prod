resource "google_bigquery_reservation" "zipline_reservation" {
  count         = var.create_bigquery_reservation ? 1 : 0
  project       = data.google_project.zipline.project_id
  location      = var.region
  name          = "${var.customer_name}-bq-bt-uploads"
  slot_capacity = 0
  autoscale {
    max_slots = 50
  }
}

resource "google_bigquery_reservation_assignment" "query_assignment" {
  count       = var.create_bigquery_reservation ? 1 : 0
  assignee    = "projects/${data.google_project.zipline.project_id}"
  job_type    = "QUERY"
  reservation = google_bigquery_reservation.zipline_reservation[0].id
  depends_on  = [google_bigquery_reservation.zipline_reservation]
}