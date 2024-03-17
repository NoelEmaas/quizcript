#!/bin/bash

function read_database() {
    # read the existing JSON file
    json_data=$(cat database.json)
}

function get_question() {
    local quiz_id="$1"
    local question_id="$2"

    read_database

    # extract the question
    question=$(echo "$json_data" | ./jq --raw-output --argjson qid "$quiz_id" --argjson quid "$question_id" '.quizzes[$qid].questions[$quid].question')

    # return the question
    echo "$question"
}

function get_all_questions() {
    local quiz_id="$1"

    read_database

    # extract the questions
    questions=$(echo "$json_data" | ./jq --raw-output --argjson qid "$quiz_id" '.quizzes[$qid].questions[].question')

    # return the questions
    echo "$questions"
}

function get_answer() {
    local quiz_id="$1"
    local question_id="$2"

    read_database

    # extract the answer
    answer=$(echo "$json_data" | ./jq --raw-output --argjson qid "$quiz_id" --argjson quid "$question_id" '.quizzes[$qid].questions[$quid].answer')

    # return the answer
    echo "$answer"
}

function get_all_answers() {
    local quiz_id="$1"

    read_database

    # extract the answers
    answers=$(echo "$json_data" | ./jq --raw-output --argjson qid "$quiz_id" '.quizzes[$qid].questions[].answer')

    # return the answers
    echo "$answers"
}

function get_question_count() {
    local quiz_id="$1"

    read_database

    # extract the question count
    question_count=$(echo "$json_data" | ./jq --argjson qid "$quiz_id" '.quizzes[$qid].questions | length')

    # return the question count
    echo $question_count
}

function get_quiz_title() {
    local quiz_id="$1"

    read_database

    # extract the quiz title
    quiz_title=$(echo "$json_data" | ./jq --raw-output --argjson qid "$quiz_id" '.quizzes[$qid].title')

    # return the quiz title
    echo "$quiz_title"
}

function get_number_of_quizzes() {
    read_database

    # extract the number of quizzes
    number_of_quizzes=$(echo "$json_data" | ./jq '.quizzes | length')

    # return the number of quizzes
    echo "$number_of_quizzes"
}

function get_quiz_titles() {
    read_database

    # extract the quiz titles
    quiz_titles=$(echo "$json_data" | ./jq --raw-output '.quizzes[].title')

    # return the quiz titles
    echo "$quiz_titles"
}

function add_quiz() {
    local quiz_title="$1"

    read_database

    # create a new quiz object
    new_quiz=$(./jq -n --arg title "$quiz_title" '{title: $title, questions: []}')

    # append the new quiz to the "quizzes" array
    updated_data=$(echo "$json_data" | ./jq ".quizzes += [$new_quiz]")

    # update the JSON file
    echo "$updated_data" > database.json
}

function add_question() {
    local quiz_id="$1"
    local question="$2"
    local answer="$3"

    read_database

    # create a new question object
    new_question=$(./jq -n --arg q "$question" --arg a "$answer" '{question: $q, answer: $a}')

    # append the new question to the specified quiz
    updated_data=$(echo "$json_data" | ./jq ".quizzes[$quiz_id].questions += [$new_question]")

    echo "$updated_data" > database.json
}

function edit_quiz_title() {
    local quiz_id="$1"
    local new_title="$2"
    
    read_database

    # update the quiz title
    updated_data=$(echo "$json_data" | ./jq --argjson qid "$quiz_id" --arg title "$new_title" '.quizzes[$qid].title = $title')

    # update the JSON file
    echo "$updated_data" > database.json
}

function edit_question() {
    local quiz_id="$1"
    local question_id="$2"
    local new_question="$3"
    
    read_database

    # update the question
    updated_data=$(echo "$json_data" | ./jq --argjson qid "$quiz_id" --argjson quid "$question_id" --arg q "$new_question" '.quizzes[$qid].questions[$quid].question = $q')

    # update the JSON file
    echo "$updated_data" > database.json
}

function edit_answer() {
    local quiz_id="$1"
    local question_id="$2"
    local new_answer="$3"

    read_database

    # update the answer
    updated_data=$(echo "$json_data" | ./jq --argjson qid "$quiz_id" --argjson quid "$question_id" --arg a "$new_answer" '.quizzes[$qid].questions[$quid].answer = $a')

    # update the JSON file
    echo "$updated_data" > database.json
}

function delete_quiz() {
    local quiz_id="$1"

    read_database

    # remove the specified quiz from the "quizzes" array
    updated_data=$(echo "$json_data" | ./jq "del(.quizzes[$quiz_id])")

    # update the JSON file
    echo "$updated_data" > database.json
}


function delete_question() {
    local quiz_id="$1"
    local question_id="$2"
    
    read_database

    # remove the specified question from the "questions" array
    updated_data=$(echo "$json_data" | ./jq --argjson qid "$quiz_id" --argjson quid "$question_id" 'del(.quizzes[$qid].questions[$quid])')

    # update the JSON file
    echo "$updated_data" > database.json
}
