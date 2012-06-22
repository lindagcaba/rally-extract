require 'rally_rest_api'
require 'date'
require 'csv'


def write_description_and_tasks(folder, us) 
  description = us.description
  tasks = us.tasks.to_s

  File.new(folder + '/' + us.formatted_i_d, 'w+').write("#{description}\n\n#{tasks}")
end

def write_history(folder, us) 

  history = us.revision_history.revisions.inject("") { |str, rev| str += '\n' + rev.description }

  File.new(folder + '/' + us.formatted_i_d, 'w+').write(history)
end

def process_story(us, rows) 
  story_description_folder = 'desc'
  history_folder = 'hist'

  execution_time = (DateTime.parse(us.accepted_date) - DateTime.parse(us.in_progress_date)).to_f

  rows << [us.formatted_i_d, us.name, us.project, us.owner, us.in_progress_date, us.accepted_date, execution_time, us.defects ? us.defects.size : 0, us.tasks ? us.tasks.size : 0]

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

project = rally.find(:project) {
  equal :name, 'NPMT Scrum Team'
}.first

results = rally.find(:hierarchicalrequirement) {
#  equal :project, project
  _or_ {
    equal :schedule_state, 'Signed-Off'
    equal :schedule_state, 'Accepted'
  }
}


rows = []
results.each do |us|
  if us.in_progress_date && us.accepted_date 
    process_story(us, rows)
  end
end

header = ['id', 'name', 'project', 'owner', 'start', 'end', 'execution_in_days', 'defects', 'tasks']
CSV.open("out.csv", "w") do |csv|
  csv << header
  rows.each {|row| csv << row}
end
