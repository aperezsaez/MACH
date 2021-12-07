class DonationsController < ApplicationController
  require 'json'
  require 'net/http'
  require 'uri'

  skip_before_action :verify_authenticity_token
  before_action :set_donation, only: %i[ show edit update destroy check_donation]

  # GET /donations or /donations.json
  def index
    @donations = Donation.all
  end

  # GET /donations/1 or /donations/1.json
  def show
    @qrcode = RQRCode::QRCode.new(@donation.payment_url)

    @svg = @qrcode.as_svg(
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 6
    )
  end

  def check_donation
    url = URI("https://biz.soymach.com/payments/#{@donation.code}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["Authorization"] = ENV["mach_key_production"]

    response = http.request(request)
    response_body = JSON.parse(response.body)
    
    respond_to do |format|
      if response_body["status"] == "CONFIRMED" || response_body["status"] == "COMPLETED"
        format.html { redirect_to root_path, notice: "Buena la re pagaste" }
      elsif response_body["status"] == "PENDING"
        format.html { redirect_to @donation, notice: "Mentiroso anda a pagar" }
      else
        format.html { redirect_to @donation, notice: "Paga la pension desgraciado" }
      end
    end
  end

  # GET /donations/new
  def new
    @donation = Donation.new
  end

  # GET /donations/1/edit
  def edit
  end

  # POST /donations or /donations.json
  def create
    @donation = Donation.new(donation_params)
    @donation.status = "pending"
    #Define payload for mach
    payload = JSON.dump({
      payment: {
        amount: @donation.amount,
        message: @donation.message,
        title: @donation.title
      }
    })
    #URL for mach
    url = URI("https://biz.soymach.com/payments")
    #Create HTTP object
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    #Create request
    request = Net::HTTP::Post.new(url)
    request["Content-Type"] = 'application/json'
    request["Authorization"] = ENV["mach_key_production"]
    #Set body
    request.body = payload
    response = http.request(request)
    #Parse response
    response_body = JSON.parse(response.body)
    @donation.code = response_body["token"]
    @donation.payment_url = response_body["url"]
    #if donation is saved respond as html
    respond_to do |format|
      if @donation.save!
        format.html { redirect_to @donation, notice: "Donation was successfully created." }
      end
    end
  end

  # PATCH/PUT /donations/1 or /donations/1.json
  def update
    respond_to do |format|
      if @donation.update(donation_params)
        format.html { redirect_to @donation, notice: "Donation was successfully updated." }
        format.json { render :show, status: :ok, location: @donation }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @donation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /donations/1 or /donations/1.json
  def destroy
    @donation.destroy
    respond_to do |format|
      format.html { redirect_to donations_url, notice: "Donation was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def webhook
    donation = Donation.find_by(code: params["event_resource_id"])
    case params["event_name"] == "business-payment-completed"
    when true
      donation.status = "paid"
      donation.save!
      render json: { 
        success: true,
        message: 'Donation completed!!!!!!' 
      }, status: 200
    else
      donation.status = "failed"
      donation.save!
      render json: { 
        success: true,
        message: 'Donation not completed!!!!!!' 
      }, status: 200
    end
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_donation
      @donation = Donation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def donation_params
      params.require(:donation).permit(:amount, :title, :message)
    end
end
