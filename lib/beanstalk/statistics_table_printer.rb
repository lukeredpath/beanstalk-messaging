module Beanstalk
  class StatisticsTablePrinter
    COLUMNS = [
      ['Queue', 28],
      ['Total Jobs', 12],
      ['(Pending)', 12],
      ['(Processed)', 12]
    ]
    
    def initialize(queue_manager, title)
      @queue_manager = queue_manager
      @title = title
      @total_width = calculate_total_width
    end
    
    def render(*queue_names)
      data_rows = queue_names.collect do |queue_name|
        queue = @queue_manager.queue(queue_name)
        
        if queue.stale?
          render_row(queue_name.to_s, 'OFFLINE', 'OFFLINE', 'OFFLINE')
        else
          render_row(queue_name.to_s, queue.total_jobs, queue.number_of_pending_messages, queue.raw_stats['cmd-delete'])
        end
      end
      
      [ render_title,
        render_headers,
        data_rows.join("\n#{sd}\n"),
        dd ].join("\n")
    end
    
    private
      def sd
        '-' * @total_width
      end
      
      def dd
        '=' * @total_width
      end
      
      def render_row(*values)
        rendered_columns = []
        COLUMNS.map { |col| col[1] }.each_with_index do |width, index|
          value = values[index]
          if value.is_a?(Fixnum)
            rendered_columns << value.to_s.rjust(width)
          else
            rendered_columns << value.ljust(width)
          end
        end
        rendered_columns.join(" | ")
      end
      
      def render_headers
        [render_row(*COLUMNS.map { |col| col[0] }), sd].join("\n")
      end
      
      def render_title
        [dd, @title.ljust(@total_width), dd].join("\n")
      end
    
      def calculate_total_width
        column_width = COLUMNS.map { |col| col[1] }.inject(0) { |sum, val| sum + val }
        separators = (COLUMNS.length - 1) * 3
        column_width + separators
      end
  end
end