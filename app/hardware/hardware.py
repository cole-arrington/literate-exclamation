from flask import Flask, request, jsonify
import mysql.connector as sql
import time
import random
import threading
application = Flask(__name__)


def slow_process_to_calculate_availability(provider, name):
    time.sleep(5)
    return random.choice(['HIGH', 'MEDIUM', 'LOW'])


@application.route('/hardware/')
def hardware():
    con = sql.connect(
        host="mysql",
        user="root",
        passwd="example",
        database="rescale_hw"
    )
    c = con.cursor()
    c.execute('SELECT * from hardware')
    
    results = c.fetchall()
    
    statuses = []
    threads = []
    
    def get_status(row):
        status = {
            'provider': row[1],
            'name': row[2],
            'availability': slow_process_to_calculate_availability(
                row[1],
                row[2]
            )
        }
        statuses.append(status)

    for row in results:
        thread = threading.Thread(target = get_status, args = (row,))
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()

    con.close()

    return jsonify(statuses)



if __name__ == "__main__":
    application.run(host='0.0.0.0', port=5001)
