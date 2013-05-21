#!/usr/bin/python2.6
# -*- coding: utf-8 -*-
import copy
import httplib
import time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import smtplib
import os

COMMASPACE = ', '

RESPONSE_SAVE_PATH = "/var/www/xtipsru/data/www/mon.vitroot.ru/monitoring/"
MAIL_LIST = ['vitroot.fl@gmail.com']
CONFIG_PATH = '/etc/monitoring.conf'
LOG_FILE = '/var/log/monitoring.log'
UNAME = os.uname()[1]
FROM_MAIL = 'monitor@vitroot.ru'
MAIL_SUBJECT = 'Monitoring Report'



good_responses = [200, 300, 201, 202, 301,302]
good_timing = 5.5 #in seconds. Interval to get a response. Default value
bad_strings = ["mysql", "permission denied", "Ошибка соединения с базой данных"]
lt=time.localtime()
timeident=str(lt[1]) + str(lt[2]) + str(lt[3]) + str(lt[4])
host_list=[]

class Timer:
    def __enter__(self):
        self.start = time.clock()
        return self

    def __exit__(self, *args):
        self.end = time.clock()
        self.interval = self.end - self.start

def parse_config(conf=CONFIG_PATH):
    config=open(conf, 'r')
    curr_host="none"
    host_cortage=["name","host",[] , copy.copy(bad_strings), "/", "http", 80, good_timing]
    parsing_good = False
    parsing_bad = False
    timing=5.0

    for row in config:
        words=row.split()
        if row.strip() == "":
            continue
        if row.startswith("#"):
            continue
        if words[0] == "check":
            parsing_bad = False
            parsing_good = True
            continue
        if words[0] == "avoid":
            parsing_good = False
            parsing_bad = True
            continue

        if words[0] == "host":
            parsing_good = False
            parsing_bad = False

            curr_host = words[1]
            if host_cortage[1] != "host" and ( host_cortage[1] != curr_host):
                host_list.append(host_cortage)
                host_cortage=["name","host",[] , bad_strings, "/", "http", 80,good_timing]
            host_cortage[1] = words[1]
            continue

        if words[0] == "uri":
            host_cortage[4] = words[1]

            parsing_good = False
            parsing_bad = False
        if words[0] == "proto":

            parsing_good = False
            parsing_bad = False
            host_cortage[5] = words[1]
	if words[0] == "time":

            parsing_good = False
            parsing_bad = False
            host_cortage[7] =float(words[1])
        if words[0] == "port":
            host_cortage[6] = words[1]
            parsing_good = False
            parsing_bad = False

        if words[0] == "name":
            host_cortage[0] = words[1]
            parsing_good = False
            parsing_bad = False
        if parsing_good:
            host_cortage[2].append(row.strip())
            continue
        elif parsing_bad:
            host_cortage[3].append(row.strip())
            continue
    
    if host_cortage[1] != "host":
        host_list.append(host_cortage)
        
def check_status(name, host, check_strings=[], fail_strings=bad_strings,uri="/", proto="http", port="80", time_=5.0):
    #print host
    start_time = time.time()
    try:
        with Timer() as t:
            if proto == "https":
                conn=httplib.HTTPSConnection(host)
            else:
                conn=httplib.HTTPConnection(host)
            conn.request("GET",uri)
            response=conn.getresponse()
            body=response.read()
            if response.status == 302:
                uri=response.getheader('location')
                conn.request("GET",uri)
                response=conn.getresponse()
                body=response.read()
        timed=time.time() - start_time, "seconds"
        #print timed
    except:
        return ("failed to connect to "  + host )
    if not( response.status in good_responses):
        return "Некорректный ответ веб-сервера: %d" %(response.status)
    if timed[0] - time_ > 0  :
        return ("Слишком долгое время ответа: %f" % (timed[0]))
    result = True
    #print time_
    for key_string in check_strings:
        result = result and (key_string in body)

        if not result:
            outfn = "%s%s-%s.html" % (RESPONSE_SAVE_PATH, timeident, host)
            out=open(outfn,'w')
            try:
                out.write(body)
            finally:
                out.close()

                return("Keystring %s not found. Here is full response: http://mon.vitroot.ru/monitoring/%s-%s.html" % (key_string, timeident, host))

    for key_string in fail_strings:
        result = result and  not (key_string in body)
    if not result:
        return ("На странице найденно сообщение об ошибке (%s). Полный полученный ответ:  http://mon.vitroot.ru/monitoring/%s-%s.html" %  (key_string, timeident, host))
    return "OK"

def sendEmail(to, text):
    smtpserver = smtplib.SMTP("smtp.gmail.com",587)
    smtpserver.ehlo()
    smtpserver.starttls()
    smtpserver.ehlo
    header = 'To:' + MAIL_LIST + '\n' + 'From: ' + FROM_MAIL + '\n' + 'Subject:' + MAIL_SUBJECT + '\n'
    msg = MIMEMultipart('alternative')
    msg = MIMEText(text, 'html', 'utf-8')
    message = header + text
    s = smtplib.SMTP('localhost')
    s.sendmail(FROM_MAIL, to, message)
    s.close()
    return 0

def check_all():
    status = True
    text = 'From server: ' + UNAME +'\n'
    text += "Внимание, обнаружены проблемы: \n"
    for host_cortage in host_list:
        name = host_cortage[0]
        host = host_cortage[1]
        g_s = host_cortage[2]
        b_s = host_cortage[3]
        uri = host_cortage[4]
        prot = host_cortage[5]
        port = host_cortage[6]
	time_ = host_cortage[7]
        check = check_status(name,host,g_s,b_s,uri,prot,port,time_)
        if check != "OK":
            status = False
            text += "%s : %s - %s \n" % (name, host, check)
    if not status:
        sendEmail(MAIL_LIST, text)
        logfile = open(LOG_FILE, 'a')
        logfile.write(text + "\n")
        logfile.close()
        #print text
parse_config()
#print host_list
check_all()
#logfile = open('/var/log/monitoring.log', 'a')
#logfile.write(text + "\n")
#logfile.close()
#print text
