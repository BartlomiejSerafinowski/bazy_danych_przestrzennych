#!/bin/bash

#Przedmiot: Bazy danych przestrzennych Ćwiczenia 7-8
#Kierunek: Geoinformatyka
#Semestr: 5
#Rok: 3

#Nazwa skryptu: automatyzacja i przetwarzanie
#Służy on do automatyzacji procesów dotyczących baz danych przestrzennych
#Wykonany został na rozszerzeniu WSL2 dla Windows, w systemie Debian

#Autor: Bartłomiej Serafinowski
#Utworzono: 18.12.2021

# 2 - Przygotowanie zmiennych
folder_domyslny=`pwd`
PROCESSED=$folder_domyslny/processed
mkdir -p $folder_domyslny
mkdir -p $PROCESSED
plikcsv=$folder_domyslny/Customers_old.csv
TIMESTAMP=`date +'%m-%d-%Y'`
logi=$folder_domyslny/etl_${TIMESTAMP}.log
url=https://home.agh.edu.pl/~wsarlej/Customers_Nov2021.zip
nazwapliku=$(echo $url | awk -F  "/" '{print $5}' | cut -f1 -d".") #awk -F wyciąga konkretne pola dla separatora, cut -f wyciąga określon epola, -d standardowy to separator
sciezkapliku=$folder_domyslny/$nazwapliku
haslozip=agh
numerindeksu=401126
aktualnyczas= `date +%T`

polaczenie="psql postgresql://<postgres>:<0938>@<localhost>/<cw7_8> << EOF"
sqlhost=localhost
sqluser=postgres
sqlhaslo=0938

#1a pobieranie
wget -nv $url -P $folder_domyslny
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - pobranie udane" >> $logi
fi

#1b rozpakowanie
unzip -qq -o -P "agh" $folder_domyslny/Customers_Nov2021.zip -d $folder_domyslny/$nazwapliku
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - rozpakowanie udane" >> $logi
fi

#1c sprawdzanie poprawności, usuwanie pustych linii, porównanie plików

cat $plikcsv $folder_domyslny/$nazwapliku | tr -d "'" > $folder_domyslny/walidacja.csv
awk 'NF' $folder_domyslny/walidacja.csv > $folder_domyslny/bezpustych.csv
awk 'dup[$0]++ == 1' $folder_domyslny/bezpustych.csv > "$folder_domyslny/Customers_Nov2021.bad_$TIMESTAMP"
awk 'NF' $folder_domyslny/$nazwapliku | tail -n +2 | grep -Fvxf "$folder_domyslny/Customers_Nov2021.bad_$TIMESTAMP" $folder_domyslny/bezpustych.csv > poprawny.csv
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - sprawdzanie poprawnosci udane" >> $logi
fi
ilosclini='wc -l < $folder_domyslny/$nazwapliku'

# 1d tworzenie tabeli w bazie danych

$polaczenie -c "CREATE EXTENSION IF NOT EXISTS postgis;"
$polaczenie -c "CREATE TABLE IF NOT EXISTS CUSTOMERS_${numerindeksu} (imie varchar(15), nazwisko varchar(50), email varchar(50), geom geography(Point) );"
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - tworzenie tabeli udane" >> $logi
fi

# 1e ładowanie danych ze zweryfikowanego pliku do tabeli
# tego punktu nie udało mi się wykonać

# 1g email z raportem 

email1=  "liczba wierszy w pobranym pliku: $ilosclini
	liczba poprawnych wierszy: 'wc -l < poprawny.csv'
        liczba duplikatów w pliku wejściowym: 'wc -l < "$folder_domyslny/$nazwapliku.bad_$TIMESTAMP"'
        ilość danych załadowanych do tabeli: "

echo $email1 | mailx -s "[$TIMESTAMP] CUSTOMERS LOAD" bartek5xd@gmail.com
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - wysylanie maila udane" >> $logi
fi

# 1h kwerenda SQL, która znajduje imiona klientów w promieniu 50 km od miejsca 

SQL_QUERY=
	"SELECT imie, nazwisko INTO BEST_CUSTOMERS_${numerindeksu} 
	FROM customers_${numerindeksu}
	WHERE st_distancespheroid(
	geom::geometry,
	'SRID=4326;POINT(41.39988501005976 -75.67329768604034)'::geometry,
	'SPHEROID["\""WGS 84"\"",6378137,298.257223563]'
	)/1000<50; "

$polaczenie " ${SQL_QUERY}"
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - wykonanie kwerendy udane" >> $logi
fi

# 1i eksportowanie zawartości tabeli BEST_CUSTOMERS do pliku csv

$polaczenie -c "COPY BEST_CUSTOMERS_${numerindeksu}" > $folder_domyslny/BEST_CUSTOMERS_${numerindeksu}.csv 
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - eksport udany" >> $logi
fi

# 1j kompresja wyeksportowanego pliku csv

zip ${folder_domyslny}/BEST_CUSTOMERS_${numerindeksu}.zip $folder_domyslny/BEST_CUSTOMERS_${numerindeksu}.csv 
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - kompresja udana" >> $logi
fi

# 1k wysyłanie skompresowanego pliku z raportem do adresata poczty

echo "data ostatniej modyfikacji: ${aktualnyczas} 
	ilosc wierszy w pliku .csv: 'wc -l < folder_domyslny/BEST_CUSTOMERS_${numerindeksu}.csv' " |
	mailx -a BEST_CUSTOMERS_${numerindeksu}.zip bartek5xd@gmail.com 
if [ "$?" -eq "0" ]
then
    echo "[${aktualnyczas}] - wysylanie maila udane" >> $logi
fi
