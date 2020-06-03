require "open-uri"
require "google/apis/drive_v3"
require "google/apis/sheets_v4"
require "google/api_client/client_secrets.rb"
require "google/apis/script_v1"
require "googleauth"
require "google/apis/slides_v1"
require "docx"

module Users
  class DocumentsController < BaseController
    APPLICATION_NAME = "Remove Bookmarks".freeze

    def today_string
      Date.current.strftime("%Y%m%d")
    end
    def index
      google_authorization = GoogleAuthorization.new(current_user).authorize
      drive_service = ::Google::Apis::DriveV3::DriveService.new
      drive_service.authorization = google_authorization
      app_script = Google::Apis::ScriptV1::ScriptService.new
      app_script.client_options.application_name = APPLICATION_NAME
      app_script.authorization = google_authorization

      begin
        files = drive_service.list_files(q: "\'#{current_user.email}\' in owners and trashed = false").files
        @spreadsheets = files.select { |f| f.mime_type == "application/vnd.google-apps.spreadsheet" }
      rescue Google::Apis::ClientError
        flash[:notice] = "Please sign in google drive to continue"
      end

      return unless params[:spreadsheet_id]
      sheets_service = ::Google::Apis::SheetsV4::SheetsService.new
      sheets_service.authorization = google_authorization
      spreadsheet_id = params[:spreadsheet_id]
      results = sheets_service.batch_get_spreadsheet_values(spreadsheet_id, ranges: "B4:AC1000").value_ranges.first.values
      results.each do |result|
        doc = Docx::Document.open("#{Rails.root}/public/document_automation.docx")
        folder_id = if result[19].include?("open")
                      result[19].split("/")[3].split("=")[1]
                    elsif result[19].include?("view")
                      result[19].split("/")[5]
                    else
                      result[19].split("/")[5].split("?")[0]
                    end

        time = result[1].split("/")
        doc.bookmarks["year"].insert_text_after(time[0])
        doc.bookmarks["month"].insert_text_after(time[1])
        doc.bookmarks["day"].insert_text_after(time[2])
        doc.bookmarks["address"].insert_text_after(result[15])
        doc.bookmarks["company"].insert_text_after(result[5])
        doc.bookmarks["chief"].insert_text_after(result[11])
        doc.bookmarks["price"].insert_text_after(result[9])
        source = "#{Rails.root}/public/documents/広報活動委託契約書[#{result[6]}].docx"
        doc.save(source)
        file_name = "広報活動委託契約書[#{result[6]}]_#{today_string}"
        file_metadata = {
          name: file_name,
          mime_type: "application/vnd.google-apps.document",
          parents: [folder_id],
        }
        begin
          retries ||= 0
          file = drive_service.create_file(file_metadata, fields: "id", upload_source: source)
          # script_id = "1WIw1xIro68E9G4Pfl8gLzluHIoSMzS57jy_S1OtXltH3i6ZkERUMBeDe"
          # document_id = [file.id]
          # request = Google::Apis::ScriptV1::ExecutionRequest.new(function: "removeBookmark", parameters: [document_id])
          # response = app_script.run_script(script_id, request)
          # if response.error
          #   p "Error detail: #{response.error.details}"
          # else
          #   p "Remove bookmarks successfully"
          # end
        rescue StandardError => e
          puts "Retry in upload_to_drive result with error: #{e.message}, after 5 secs..."
          sleep(5)
          retry if (retries += 1) < 3
        end
      end
      FileUtils.rm_rf(Dir.glob("#{Rails.root}/public/documents/*"))
      flash[:notice] = "Automate successfully! Please check results in your drive"
      redirect_to users_documents_path
    end
  end
end
