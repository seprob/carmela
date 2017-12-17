#!/bin/bash

# Sprawdz czy uzytkownik jest rootem.

if [ "$(id -u)" -ne "0" ] # Jezeli nie jest zalogowany jako root.
then
   echo "[*] Carmela 1 to narzedzie do przywracania tylko jednej lub kilku roznych tabel lub keyspace'ow Cassandry z kopii zapasowej."

   echo "[!] Nie jestes zalogowany jako root!"

   exit 1 # Wyjscie z kodem bledu.
fi

while getopts :k:t:d:b:c:h argument; do
   case $argument in
      k)
         # Nazwa przestrzeni.

         keyspace=$OPTARG

         ;;
      t)
         # Nazwa tabeli.

         table=$OPTARG

         ;;
      d)
         # Katalog z keyspace'ami.

         keyspace_home=$OPTARG

         ;;
      b)
	 # Katalog z danymi kopii zapasowej (do odzyskania).

         data=$OPTARG

         ;;
      c)
         # Katalog "commitlog".

         commitlog_directory=$OPTARG

         ;;
      h)
         echo "[*] Carmela 1 to narzedzie do przywracania tylko jednej lub kilku roznych tabel lub keyspace'ow Cassandry z kopii zapasowej."

         echo "[*] Wywolanie: \"$0 -k nazwa_przestrzeni -t nazwa_tabeli -d sciezka_do_katalogu_z_keyspace'ami -b sciezka_do_katalogu_z_danymi_kopii_zapasowej -c katalog_commitlog\"."

         exit 1

         ;;
      \?)
         echo "[!] Nieznana opcja (wywolanie: \"$0 -k nazwa_przestrzeni -t nazwa_tabeli -d sciezka_do_katalogu_z_keyspace'ami -b sciezka_do_katalogu_z_danymi_kopii_zapasowej -c katalog_commitlog\")!"

         ;;
   esac
done

shift $((OPTIND-1)) # Powiedz getopts aby przeszedl do nastepnego argumentu.

# Sprawdz czy katalog domowy bazy danych istnieje.

if [ ! -d "$keyspace_home" ]
then
   echo "[!] Katalog z keyspace'ami Cassandry \"$keyspace_home\" nie istnieje."

   exit 1
fi

# Sprawdz czy podana przestrzen istnieje.

if [ ! -d "$keyspace_home/$keyspace" ]
then
   echo "[!] Podana przestrzen nie istnieje!"

   exit 1
fi

# Sprawdz czy podana tabela istnieje (pobierz ostatni stworzony katalog z przedroskiem nazwy tabeli).

table_directory=$(ls -t "$keyspace_home/$keyspace" | grep ^$table- | head -1)

if [ $? -ne 0 ]
then
   echo "[!] Podana tabela nie istnieje!"

   exit 1
fi

# Sprawdz czy podana sciezka z danymi kopii zapasowych istnieje.

if [ ! -d "$data" ]
then
   echo "[!] Katalog \"$data\" z danymi kopii zapasowej nie istnieje!"

   exit 1
fi

# Sprawdz czy Cassandra jest uruchomiona.

if nodetool status > /dev/null 2>&1
then
   read -r -p "[?] Czy chcesz zatrzymac Cassandre (pozostanie wylaczona po zakonczeniu dzialania program)? Odpowiedz \"t\" lub \"n\": " response

   case $response in
      t)
         service cassandra stop > /dev/null # Zatrzymaj Cassandre.

         ;;
      *)
         echo "[!] Cassandra musi byc wylaczona aby wgrac kopie zapasowa!"

         exit 1

         ;;
   esac
fi

# Usun "commitlog".

if [ ! -d "$commitlog_directory" ]
then
   echo "[!] Katalog commitlog \"$commitlog_directory\" nie istnieje."

   exit 1
else
   rm -fr "${commitlog_directory:?}/"*
fi

# Sprawdz czy w katalogu z migawka sa pliki o rozszerzeniu "db".

mapfile -t count_db_files < <(find "$data" -maxdepth 1 -name "*.db")

if [ ${#count_db_files[@]} -gt 0 ] # Jezeli sa tam jakies pliki o rozszerzeniu "db".
then
   # Przywracamy kopie zapasowa.

   rm -fr "$keyspace_home/$keyspace/$table_directory"/*.db

   cp "$data"/*.db "$keyspace_home/$keyspace/$table_directory/"

   chown cassandra:cassandra "$keyspace_home/$keyspace/$table_directory"/*
fi