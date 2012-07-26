require 'rally_rest_api'
require 'date'
require 'csv'

def strip_tags(str)
  str.gsub(/<[^>]*>/, '')
end

def write_description_and_tasks(folder, us) 
  description = us.description
  tasks = us.tasks.to_s

  File.new(folder + '/' + us.formatted_i_d, 'w+').write(strip_tags("#{description}\n\n#{tasks}"))
end

def write_history(folder, us) 

  history = us.revision_history.revisions.inject("") { |str, rev| str += '\n' + rev.description }

  File.new(folder + '/' + us.formatted_i_d, 'w+').write(strip_tags(history))
end

def process_story(us, rows) 
  story_description_folder = 'desc'
  history_folder = 'hist'

  execution_time = (DateTime.parse(us.accepted_date) - DateTime.parse(us.in_progress_date)).to_f
  acceptance_criteria = us.description.to_s.scan("<LI>").size + us.description.to_s.scan("<li>").size 
  qa_tasks = 0
  unless us.tasks.nil?
    i = 0
    while i < us.tasks.size
      qa_tasks += us.tasks[i].to_s.scan("test").size
      qa_tasks += us.tasks[i].to_s.scan("verify").size
      qa_tasks += us.tasks[i].to_s.scan("QA").size
      i += 1
    end
  end

  rows << [us.formatted_i_d, us.name, us.project, us.owner, us.in_progress_date, us.accepted_date, execution_time, us.defects ? us.defects.size : 0, us.tasks ? us.tasks.size : 0, us.plan_estimate ? us.plan_estimate : 0, us.package, us.task_estimate_total, acceptance_criteria, us.attachments ? us.attachments.size : 0, qa_tasks, us.test_cases ? us.test_cases.size : 0, us.description ? us.description.size : 0 ]

  write_description_and_tasks(story_description_folder, us)
  write_history(history_folder, us)
end

username = ARGV[0]
password = ARGV[1]

params = {
  :username => username,
  :password => password,
  :version => 'x'
}

rally = RallyRestAPI.new(params)

#project = rally.find(:project) {
#  equal :name, 'NPMT Scrum Team'
#}.first

results = rally.find(:hierarchicalrequirement) {
#  equal :project, project
  _or_ {
    equal :schedule_state, 'Signed-Off'
    equal :schedule_state, 'Accepted'
  }
}


rows = []
results.each do |us|
  in_progress_date = ""
  us.revision_history.revisions.each do |rev|
    in_progress_date = rev.creation_date if /.*IN PROGRESS DATE added.*/.match(rev.description)
  end
  
  in_progress_date = us.in_progress_date if in_progress_date.empty?
  print "."
  if in_progress_date && us.accepted_date
    puts "------------Story:" + us.formatted_i_d
    puts "------------DATE: " + in_progress_date
    execution_time = (DateTime.parse(us.accepted_date) - DateTime.parse(in_progress_date)).to_f
    if (execution_time > 0) && (us.children.nil?)
      us.in_progress_date = in_progress_date
      process_story(us, rows)
    end
  end
end

header = ['id', 'name', 'project', 'owner', 'start', 'end', 'execution_in_days', 'defects', 'tasks', 'plan_estimate', 'package', 'task_estimate_total', '# acceptance criteria', '# attachements', '# qa tasks', '# test cases', 'length of description' ]
CSV.open("out.csv", "w") do |csv|
  csv << header
  rows.each {|row| csv << row}
end
