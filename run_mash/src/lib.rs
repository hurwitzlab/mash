extern crate clap;
extern crate csv;
extern crate tempfile;
extern crate walkdir;

use clap::{App, Arg};
use std::collections::HashMap;
use std::error::Error;
use std::process::{Command, Stdio};
use std::{
    env, fs::{self, DirBuilder, File}, io::Write, path::{Path, PathBuf},
};
use walkdir::WalkDir;

// --------------------------------------------------
type Record = HashMap<String, String>;

// --------------------------------------------------
#[derive(Debug)]
pub struct Config {
    alias_file: Option<String>,
    bin_dir: Option<String>,
    kmer_size: Option<u32>,
    sketch_size: Option<u32>,
    num_threads: Option<u32>,
    out_dir: PathBuf,
    query: Vec<String>,
}

type MyResult<T> = Result<T, Box<Error>>;

// --------------------------------------------------
pub fn run(config: Config) -> MyResult<()> {
    let files = find_files(&config.query)?;
    println!(
        "Will process {} file{}",
        files.len(),
        if files.len() == 1 { "" } else { "s" }
    );

    let out_dir = &config.out_dir;
    if !out_dir.is_dir() {
        DirBuilder::new().recursive(true).create(&out_dir)?;
    }

    let sketches = sketch_files(&config, &files)?;
    let fig_dir = pairwise_compare(&config, &sketches)?;

    println!("Done, see figures in {}", fig_dir);

    Ok(())
}

// --------------------------------------------------
pub fn get_args() -> MyResult<Config> {
    let matches = App::new("Mash All vs All")
        .version("0.1.0")
        .author("Ken Youens-Clark <kyclark@email.arizona.edu")
        .about("Run Mash all-vs-all")
        .arg(
            Arg::with_name("query")
                .short("q")
                .long("query")
                .value_name("FILE_OR_DIR")
                .help("File or input directory")
                .required(true)
                .min_values(1),
        )
        .arg(
            Arg::with_name("out_dir")
                .short("o")
                .long("out_dir")
                .value_name("DIR")
                .help("Output directory"),
        )
        .arg(
            Arg::with_name("alias")
                .short("a")
                .long("alias")
                .value_name("FILE")
                .help("Aliases for sample names"),
        )
        .arg(
            Arg::with_name("kmer_size")
                .short("k")
                .long("kmer_size")
                .value_name("INT")
                .default_value("21")
                .help("K-mer size"),
        )
        .arg(
            Arg::with_name("sketch_size")
                .short("s")
                .long("sketch_size")
                .value_name("INT")
                .default_value("1000")
                .help("Sketch size"),
        )
        .arg(
            Arg::with_name("num_threads")
                .short("t")
                .long("num_threads")
                .value_name("INT")
                .default_value("12")
                .help("Number of threads"),
        )
        .arg(
            Arg::with_name("bin_dir")
                .short("b")
                .long("bin_dir")
                .value_name("DIR")
                .help("Location of binaries"),
        )
        .get_matches();

    let out_dir = match matches.value_of("out_dir") {
        Some(x) => PathBuf::from(x),
        //_ => None,
        _ => {
            let cwd = env::current_dir()?;
            cwd.join(PathBuf::from("mash-out"))
        }
    };

    let alias = match matches.value_of("alias") {
        Some(x) => Some(x.to_string()),
        _ => None,
    };

    let bin_dir = match matches.value_of("bin_dir") {
        Some(x) => Some(x.to_string()),
        _ => None,
    };

    let num_threads = match matches.value_of("num_threads") {
        Some(x) => match x.trim().parse::<u32>() {
            Ok(n) => Some(n),
            _ => None,
        },
        _ => None,
    };

    let kmer_size = match matches.value_of("kmer_size") {
        Some(x) => match x.trim().parse::<u32>() {
            Ok(n) => Some(n),
            _ => None,
        },
        _ => None,
    };

    let sketch_size = match matches.value_of("sketch_size") {
        Some(x) => match x.trim().parse::<u32>() {
            Ok(n) => Some(n),
            _ => None,
        },
        _ => None,
    };

    let config = Config {
        alias_file: alias,
        bin_dir: bin_dir,
        num_threads: num_threads,
        kmer_size: kmer_size,
        sketch_size: sketch_size,
        out_dir: out_dir,
        query: matches.values_of_lossy("query").unwrap(),
    };

    Ok(config)
}

// --------------------------------------------------
fn find_files(paths: &Vec<String>) -> Result<Vec<String>, Box<Error>> {
    let mut files = vec![];
    for path in paths {
        let meta = fs::metadata(path)?;
        if meta.is_file() {
            files.push(path.to_owned());
        } else {
            for entry in fs::read_dir(path)? {
                let entry = entry?;
                let meta = entry.metadata()?;
                if meta.is_file() {
                    files.push(entry.path().display().to_string());
                }
            }
        };
    }

    if files.len() == 0 {
        return Err(From::from("No input files"));
    }

    Ok(files)
}

// --------------------------------------------------
fn sketch_files(config: &Config, files: &Vec<String>) -> MyResult<Vec<String>> {
    let sketch_dir = config.out_dir.join(PathBuf::from("sketches"));
    if !sketch_dir.is_dir() {
        DirBuilder::new().recursive(true).create(&sketch_dir)?;
    }

    let num_threads = match config.num_threads {
        Some(n) if n > 0 && n < 64 => n,
        _ => 12,
    };

    let kmer_size = match config.kmer_size {
        Some(n) => n,
        _ => 21,
    };

    let sketch_size = match config.sketch_size {
        Some(n) => n,
        _ => 1000,
    };

    let aliases = get_aliases(&config.alias_file)?;
    let mut jobs = vec![];

    for file in files.iter() {
        let basename = basename(&file, &aliases);
        let out_file = sketch_dir.join(basename);
        let mash_file = format!("{}.msh", out_file.display());

        if !Path::new(&mash_file).exists() {
            jobs.push(format!(
                "mash sketch -p {} -o {} -s {} -k {} {}",
                num_threads,
                out_file.display(),
                sketch_size,
                kmer_size,
                file
            ));
        }
    }

    run_jobs(&jobs, "Sketching files", 8)?;

    let mut sketches: Vec<String> = WalkDir::new(sketch_dir)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| !e.file_type().is_dir())
        .map(|e| e.path().display().to_string())
        .collect();

    sketches.sort();

    if files.len() != sketches.len() {
        return Err(From::from("Failed to create all sketches"));
    }

    Ok(sketches)
}

// --------------------------------------------------
fn run_jobs(jobs: &Vec<String>, msg: &str, num_concurrent: u32) -> MyResult<()> {
    let num_jobs = jobs.len();

    if num_jobs > 0 {
        println!(
            "{} (# {} job{} @ {})",
            msg,
            num_jobs,
            if num_jobs == 1 { "" } else { "s" },
            num_concurrent
        );

        let mut process = Command::new("parallel")
            .arg("-j")
            .arg(num_concurrent.to_string())
            .arg("--halt")
            .arg("soon,fail=1")
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .spawn()?;

        {
            let stdin = process.stdin.as_mut().expect("Failed to open stdin");
            stdin
                .write_all(jobs.join("\n").as_bytes())
                .expect("Failed to write to stdin");
        }

        let result = process.wait()?;
        if !result.success() {
            return Err(From::from("Failed to run jobs in parallel"));
        }
    }

    Ok(())
}

// --------------------------------------------------
fn pairwise_compare(config: &Config, sketches: &Vec<String>) -> MyResult<String> {
    println!("Comparing sketches");

    let fig_dir = config.out_dir.join(PathBuf::from("figures"));
    if !fig_dir.is_dir() {
        DirBuilder::new().recursive(true).create(&fig_dir)?;
    }

    let sketch_list = fig_dir.join("sketches.txt");
    let tmpfile = File::create(&sketch_list)?;

    for sketch in sketches {
        writeln!(&tmpfile, "{}", sketch).unwrap();
    }

    let all_mash = fig_dir.join(PathBuf::from("all.msh"));
    if all_mash.exists() {
        fs::remove_file(&all_mash)?;
    }

    let all_mash_no_ext = fig_dir.join(PathBuf::from("all"));

    let paste = Command::new("mash")
        .arg("paste")
        .arg("-l")
        .arg(all_mash_no_ext)
        .arg(&sketch_list)
        .output();

    if let Err(e) = paste {
        return Err(From::from(format!("Failed to run \"mash paste\": {}", e)));
    };

    let dist_cmd = Command::new("mash")
        .arg("dist")
        .arg("-t")
        .arg(&all_mash)
        .arg(&all_mash)
        .output();

    let dist_out = match dist_cmd {
        Err(e) => {
            let msg = format!("Failed to run \"mash dist\": {}", e);
            return Err(From::from(msg));
        }
        Ok(res) => String::from_utf8_lossy(&res.stdout).to_string(),
    };

    let mash_dist = fix_mash_distance(&dist_out);
    if mash_dist.len() == 0 {
        println!("Failed to get usable output from \"mash dist\"");
    } else {
        let dist_file = fig_dir.join("distance.txt");
        let dist_fh = match File::create(&dist_file) {
            Ok(file) => file,
            Err(e) => {
                let msg = format!(
                    "Failed to write \"{}\": {}",
                    dist_file.to_string_lossy(),
                    e.to_string()
                );
                return Err(From::from(msg));
            }
        };
        write!(&dist_fh, "{}", mash_dist)?;

        let make_figures = "make_figures.r";
        let make_figures_path = match &config.bin_dir {
            Some(d) => Path::new(&d).join(make_figures),
            _ => PathBuf::from(make_figures),
        };

        println!("Making figures");
        let mk_figs = Command::new(&make_figures_path)
            .arg("-o")
            .arg(&fig_dir)
            .arg("-m")
            .arg(&dist_file)
            .output();

        if let Err(e) = mk_figs {
            let msg = format!(
                "Failed to run \"{}\": {}",
                make_figures_path.to_string_lossy(),
                e.to_string()
            );
            return Err(From::from(msg));
        };
    }

    fs::remove_file(&sketch_list).unwrap();
    fs::remove_file(&all_mash).unwrap();

    Ok(fig_dir.to_string_lossy().to_string())
}

// --------------------------------------------------
fn fix_mash_distance(s: &str) -> String {
    let mut res = vec![];
    for (i, line) in s.split("\n").enumerate() {
        res.push(if i == 0 {
            fix_mash_header(&line)
        } else {
            fix_mash_line(&line)
        });
    }

    res.join("\n")
}

// --------------------------------------------------
fn fix_mash_header(line: &str) -> String {
    let mut flds: Vec<&str> = line.split("\t").collect();
    flds[0] = "";
    let hdrs: Vec<&str> = flds.iter().map(|f| basename(f, &None)).collect();
    hdrs.join("\t")
}

// --------------------------------------------------
fn fix_mash_line(line: &str) -> String {
    let mut flds: Vec<&str> = line.split("\t").collect();
    flds[0] = basename(flds[0], &None);
    flds.join("\t")
}

// --------------------------------------------------
fn basename<'a>(filename: &'a str, aliases: &'a Option<Record>) -> &'a str {
    let mut parts: Vec<&str> = filename.split("/").collect();
    let name = match parts.pop() {
        Some(x) => x,
        None => filename,
    };

    if let Some(a) = aliases {
        match a.get(name) {
            Some(alias) => alias,
            _ => name,
        }
    } else {
        name
    }
}

// --------------------------------------------------
fn get_aliases(alias_file: &Option<String>) -> Result<Option<Record>, Box<Error>> {
    match alias_file {
        None => Ok(None),
        Some(file) => {
            let alias_fh = match File::open(file) {
                Ok(file) => file,
                Err(e) => {
                    let msg = format!("Failed to open \"{}\": {}", file, e.to_string());
                    return Err(From::from(msg));
                }
            };

            let mut aliases = HashMap::new();
            let delimiter = match Path::new(&file).extension() {
                Some(ext) => match ext.to_str() {
                    Some("csv") => b',',
                    _ => b'\t',
                },
                _ => b'\t',
            };

            let mut rdr = csv::ReaderBuilder::new()
                .delimiter(delimiter)
                .from_reader(alias_fh);

            for result in rdr.deserialize() {
                let record: Record = result?;
                let name = record.get("sample_name");
                let alias = record.get("alias");

                match (name, alias) {
                    (Some(name), Some(alias)) => {
                        aliases.insert(name.to_string(), alias.to_string());
                        ()
                    }
                    _ => println!("Missing sample_name or alias"),
                }
            }

            if aliases.len() > 0 {
                Ok(Some(aliases))
            } else {
                Ok(None)
            }
        }
    }
}
