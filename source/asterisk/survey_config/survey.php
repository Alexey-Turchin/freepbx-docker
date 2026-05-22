#!/usr/bin/php -q
<?php
#####################
# File path: /var/lib/asterisk/agi-bin/survey.php
#####################

#парсим данные из AGI
require_once('phpagi.php');
$agi = new AGI();
$num = $agi->request['agi_callerid'];
$operator = $agi->request['agi_arg_2'];
$queue = $agi->request['agi_arg_3'];
$valuation = $agi->request['agi_extension'];
$date = date("Y-m-d H:i:s");

#параметры подключения к API Telegram и групповой ID - чата
/*$token = "ваш_api_от_Telegram";
$chat_id = "ID_чата";
#массив для Telegram чата супервизоров
$arr = array(
'Получена оценка оператора клиентом:' => '',
'Звонящий:' => $num,
'Оцененный оператор:' => $operator,
'Очередь звонка:' => $queue,
'Поставлена оценка (1-5)' => $valuation,
'Дата оценки:' => $date,
);
foreach($arr as $key => $value) {
$txt .= "<b>".$key."</b> ".$value."%0A";
};
fopen("https://api.telegram.org/bot{$token}/sendMessage?chat_id={$chat_id}&parse_mode=html&text={$txt}","r");
*/

#параметры подключения к БД
$hostname = "";
$username = "";
$password = "";
$dbName = "asterisksurvey";

#парсим данные через SQL по звонкам
/* You should enable error reporting for mysqli before attempting to make a connection */
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$mysqli = new mysqli($hostname, $username, $password, $dbName);

/* Set the desired charset after establishing a connection */
$mysqli->set_charset('utf8mb4');
printf("Success... %s\n", $mysqli->host_info);
$mysqli->query("INSERT INTO `survey` (`num`, `operator`, `queue`, `valuation`, `date`) VALUES ('$num', '$operator', '$queue', '$valuation', '$date')");
//$mysqli->query("INSERT INTO `survey` (`num`, `operator`, `queue`, `valuation`, `date`) VALUES ('9922', '9000', '99900', '5', '$date')");
printf("Insert successfully done.\n");
?>