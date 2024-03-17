#!/bin/bash

# Source the backend script
source crud.sh

# Display the start screen
dialog --title "Quiz App" --msgbox "Welcome to the Quiz App!\n\nPress Enter to start." 10 40

# Loop until the user chooses to exit
while true; do
    # Get the list of available quiz titles
    quiz_titles=$(get_quiz_titles)

    # Create the menu options
    menu_options=()
    menu_options+=("Select" "Select a quiz")
    menu_options+=("Create Quiz" "Create a new quiz")
    menu_options+=("Back" "Go back to the start screen")

    # Display the quiz selection menu
    choice=$(dialog --clear --title "Quiz Selection" \
                    --menu "Choose an option:" 15 40 10 "${menu_options[@]}" \
                    2>&1 >/dev/tty)

    # Handle the user's choice
    case "$choice" in
        "Select")
            # Get the list of quiz titles again (in case a new quiz was added)
            quiz_titles=$(get_quiz_titles)

            # Display a menu to select a quiz
            selected_quiz=$(dialog --clear --title "Select Quiz" \
                                    --menu "Choose a quiz:" 15 40 10 \
                                    $(for title in $quiz_titles; do echo "$title" "$title"; done) \
                                    2>&1 >/dev/tty)

            # If a quiz was selected, proceed to the questions
            if [ -n "$selected_quiz" ]; then
                # Get the quiz ID
                quiz_id=$(get_quiz_titles | grep -n "$selected_quiz" | cut -d':' -f1 | tr -d ' ')

                # Call a function to handle the quiz questions
                handle_quiz_questions "$quiz_id"
            fi
            ;;
        "Create Quiz")
            # Prompt the user to enter a quiz title
            quiz_title=$(dialog --clear --title "Create Quiz" \
                                --inputbox "Enter the quiz title:" 10 40 \
                                2>&1 >/dev/tty)

            # Add the new quiz to the database
            add_quiz "$quiz_title"

            # Enter a loop to add questions and answers
            while true; do
                # Prompt the user to enter a question and answer using a form
                question_data=$(dialog --clear --title "Add Question" \
                                        --form "Enter the question and answer:" 15 50 0 \
                                        "Question:" 1 1 "" 1 25 25 0 \
                                        "Answer:" 2 1 "" 2 25 25 0 \
                                        2>&1 >/dev/tty)

                # Extract the question and answer from the form data
                question=$(echo "$question_data" | sed -n 1p)
                answer=$(echo "$question_data" | sed -n 2p)

                # Get the quiz ID of the newly created quiz
                quiz_id=$(get_number_of_quizzes)

                # Add the question and answer to the database
                add_question "$quiz_id" "$question" "$answer"

                # Ask if the user wants to add another question
                add_another=$(dialog --clear --title "Add Another Question" \
                                      --yesno "Do you want to add another question?" 10 40 \
                                      2>&1 >/dev/tty)

                # If the user doesn't want to add another question, break out of the loop
                [ "$add_another" != 0 ] && break
            done
            ;;
        "Back")
            # Clear the screen and display the start screen again
            clear
            dialog --title "Quiz App" --msgbox "Welcome to the Quiz App!\n\nPress Enter to start." 10 40
            ;;
        *)
            # Exit the application
            break
            ;;
    esac
done

# Function to handle the quiz questions
handle_quiz_questions() {
    local quiz_id="$1"
    local question_count=$(get_question_count "$quiz_id")
    local score=0

    # Loop through the questions
    for ((i=0; i<question_count; i++)); do
        # Get the current question and answer
        question=$(get_question "$quiz_id" "$i")
        answer=$(get_answer "$quiz_id" "$i")

        # Display the question and prompt for the user's answer
        user_answer=$(dialog --clear --title "Question $((i+1))" \
                              --inputbox "$question" 10 50 \
                              2>&1 >/dev/tty)

        # Check if the user's answer is correct
        if [ "$user_answer" == "$answer" ]; then
            score=$((score+1))
        fi
    done

    # Display the final score
    dialog --title "Quiz Results" \
           --msgbox "You scored $score out of $question_count." 10 40
}

# Call the start screen initially
dialog --title "Quiz App" --msgbox "Welcome to the Quiz App!\n\nPress Enter to start." 10 40