module ApplicationHelper
  def bootstrap_class_for_flash(flash_type)
    flash_hash = {
      success: "alert-success",
      error: "alert-danger",
      alert: "alert-warning",
      notice: "alert-info",
    }
    flash_hash[flash_type.to_sym]
  end
end
