for f in `git status | grep modified | cut -d ":" -f2`
do 
  git add $f
  echo "Add: $f"
done
