require "csv"
require "sqlite3"
require "progressbar"

STDOUT.sync = true

dbfile = "coiffeurs.sqlite"

def usage()
  puts "run sirene.rb StockEtablissement_utf8.csv StockUniteLegale_utf8.csv"
end

etab_file = ARGV[0]
if not etab_file or not File.exist?(etab_file)
  usage
  exit
end

unite_file = ARGV[1]
if not unite_file or not File.exist?(unite_file)
  usage
  exit
end

if File.exist?(dbfile)
  raise "Le fichier #{dbfile} existe déjà"
end

if not File.exist?(dbfile)
  db = SQLite3::Database.open(dbfile)
  db.transaction
  db.execute "CREATE TABLE Coiffeurs(siret TEXT UNIQUE PRIMARY KEY, siren TEXT, name TEXT, date DATE, codepostal TEXT, active BOOL, ville text, numero_rue text, voie text, lat FLOAT, lng FLOAT, global_code TEXT, blague BOOL, etat TEXT);"
  db.commit
  db.close()
end

db = SQLite3::Database.open(dbfile)


$stderr.puts "Loading extra possible names from #{unite_file}"
$stderr.puts "calculating number of lines to parse"
total = `wc -l "#{unite_file}"  | cut -d " " -f 1`.strip().to_i()
progressbar = ProgressBar.create(total: total, format: '%a %e %P% Processed: %c from %C')
extra_names = {}
i=0
CSV.foreach(ARGV[0], headers:true) do |l|
  i+=1
  begin
    progressbar.progress += 10000 if i%10000 ==0
  rescue
  end
  next if l['activitePrincipaleUniteLegale'] != "96.02A"
  nom = l['denominationUsuelle1UniteLegale'] || l['denominationUsuelle2UniteLegale'] || l['denominationUsuelle3UniteLegale']
  next unless nom
  siren = l['siren']
  extra_names[siren] = nom
end
progressbar.finish

$stderr.puts "Loading main SIRENE database from from #{etab_file}"
$stderr.puts "calculating number of lines to parse"
total = `wc -l "#{etab_file}"  | cut -d " " -f 1`.strip().to_i()
progressbar = ProgressBar.create(total: total, format: '%a %e %P% Processed: %c from %C')

i=0
CSV.foreach(etab_file, headers:true) do |line|
  i+=1
  begin
    progressbar.progress += 10000 if i%10000 ==0
  rescue
  end
  activite = line["activitePrincipaleEtablissement"]
  next unless activite
  next unless activite.start_with?("96.02A")
  name = (line["enseigne1Etablissement"] || line["enseigne2Etablissement"] || line["enseigne3Etablissement"] || line["denominationUsuelleEtablissement"] || "").strip
  siret = line["siret"]
  if name == ""
    name = extra_names[siret[0..8]]
  end
  next unless name
  codepostal = line["codePostalEtablissement"]
  date_creation = line["dateCreationEtablissement"]
  ville = line['libelleCommuneEtablissement']
  numero_rue, = line['numeroVoieEtablissement']
  type = line['typeVoieEtablissement']
  rue = line['libelleVoieEtablissement']
  etat = line['etatAdministratifEtablissement']
  db.execute("INSERT INTO Coiffeurs (siret, siren, name, date, codepostal, ville, numero_rue, voie, etat) VALUES (?,?,?,?,?,?,?,?,?)",
            siret,
            siret[0..8],
            name,
            date_creation,
            codepostal,
            ville,
            numero_rue,
            [type, rue].join(' ').strip(),
            etat
            )
end

progressbar.finish
