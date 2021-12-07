json.extract! donation, :id, :amount, :title, :message, :status, :code, :created_at, :updated_at
json.url donation_url(donation, format: :json)
