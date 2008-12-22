
######################################################################
### Auto Nested Layout
ActionController::Base.class_eval do
  class << self
    def nested_layout(files = ['application'], options = {})
      if files.blank?
        # 対象ファイルが指定されていなければ ['layouts/application'] にする
        files = ['layouts/application']
      else
        # ひとつめのファイルは layouts 以下に置かれているものにする
        files[0] = 'layouts/' + files[0]
      end
      
      layout false
      
      filter = NestedLayoutFilter.new
      filter.layouts = files
      filter.layouts_mobile = files.collect{|layout| layout + '_mobile'}
      
      around_filter filter, options
        # around_filter に変更　jpmobile との関係での文字化けに対応
        # options 追加
    end
  end
  
  def render_with_nested_layouts(layouts)
    return true if guard_from_nested_layouts

    if layouts.size <= 1
      guess_layouts = guess_nested_layouts
      guess_layouts.collect!{|layout| layout + '_mobile'} if request.mobile?
      layouts.concat(guess_layouts)
      layouts.reverse!
    end

    logger.debug "Rendering nested layouts %s" % layouts.inspect

    layouts.each do |layout|
      content_for_layout = response.body
      erase_render_results
      add_variables_to_assigns
      @template.instance_variable_set("@content_for_layout", content_for_layout)
      render :partial => layout
    end
  end
      
private
  def guard_from_nested_layouts
    return true if @before_filter_chain_aborted
    return true if @performed_redirect
    return true if request.xhr?
    return true if !action_has_layout?
    return false
  end

  def guess_nested_layouts
    layouts      = [Pathname("/")]
    partial_path = @template.send(:partial_pieces, "layout").first
    partial_path.split('/').each{|dir| layouts << layouts.last + dir unless dir.to_s == "."}
    
    if request.mobile?
      layouts.reject!{|path| !(Pathname(RAILS_ROOT) + "app/views#{path}" + "_layout_mobile.rhtml").exist? }
    else
      layouts.reject!{|path| !(Pathname(RAILS_ROOT) + "app/views#{path}" + "_layout.rhtml").exist? }
    end
    return layouts.reverse.map{|i| (i+"layout").to_s}
  end

  # 追加
  class NestedLayoutFilter
    attr_accessor :layouts, :layouts_mobile
    
    def before(controller)
      controller.class.layout false
      return
    end
    
    def after(controller)
      if controller.request.mobile?
        controller.render_with_nested_layouts(layouts_mobile)
      else
        controller.render_with_nested_layouts(layouts)
      end
    end
  end
end

