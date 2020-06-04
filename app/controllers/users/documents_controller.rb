require "open-uri"
require "google/apis/drive_v3"
require "google/apis/sheets_v4"
require "google/api_client/client_secrets.rb"
require "google/apis/script_v1"
require "googleauth"
require "google/apis/slides_v1"
require "google/apis/docs_v1"
require "googleauth/stores/file_token_store"
require "fileutils"

module Users
  class DocumentsController < BaseController
    def today_string
      Date.current.strftime("%Y%m%d")
    end

    def index
      google_authorization = GoogleAuthorization.new(current_user).authorize
      drive_service = ::Google::Apis::DriveV3::DriveService.new
      drive_service.authorization = google_authorization
      document_service = ::Google::Apis::DocsV1::DocsService.new
      document_service.authorization = google_authorization
      sheets_service = ::Google::Apis::SheetsV4::SheetsService.new
      sheets_service.authorization = google_authorization

      begin
        files = drive_service.list_files(q: "\'#{current_user.email}\' in owners and trashed = false").files
        @spreadsheets = files.select { |f| f.mime_type == "application/vnd.google-apps.spreadsheet" }
      rescue Google::Apis::ClientError
        flash[:notice] = "Please sign in google drive to continue"
      end

      return unless params[:spreadsheet_id]

      spreadsheet_id = params[:spreadsheet_id]
      results = sheets_service.batch_get_spreadsheet_values(spreadsheet_id, ranges: "B4:AC1000").value_ranges.first.values
      results.each do |result|
        folder_id = if result[19].include?("open")
                      result[19].split("/")[3].split("=")[1]
                    elsif result[19].include?("sharing")
                      result[19].split("/")[5].split("?")[0]
                    else
                      result[19].split("/")[5]
                    end
        time = result[1].split("/")

        begin
          document_id = create_document(result, folder_id, drive_service)
          requests = []
          requests << replace_text(time[0], "year")
          requests << replace_text(time[1], "month")
          requests << replace_text(time[2], "day")
          requests << replace_text(result[15], "address")
          requests << replace_text(result[5], "company")
          requests << replace_text(result[11], "chief")
          requests << replace_text(result[9], "price")

          req = Google::Apis::DocsV1::BatchUpdateDocumentRequest.new(requests: requests)
          document_service.batch_update_document(document_id, req)
        rescue StandardError => e
          puts "Retry in upload_to_drive result with error: #{e.message}, after 5 secs..."
          sleep(5)
          retry if (retries += 1) < 3
        end
      end
      flash[:notice] = "Automate successfully! Please check results in your drive"
      redirect_to users_documents_path
    end

    def create_document(result, folder_id, drive_service)
      file_metadata = {
        name: "広報活動委託契約書[#{result[6]}]_#{today_string}",
        mime_type: "application/vnd.google-apps.document",
        parents: [folder_id],
      }

      template_file = "#{Rails.root}/public/automation_document.docx"
      file = drive_service.create_file(
        file_metadata,
        fields: "id",
        upload_source: template_file,
        content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      )
      file.id
    end

    def replace_text(result, text)
      {
        replace_all_text: {
          replace_text: result.to_s,
          contains_text: {
            text: "{{#{text}}}",
            match_case: true
          }
        }
      }
    end
  end
end
